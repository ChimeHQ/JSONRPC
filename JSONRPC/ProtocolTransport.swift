import Foundation
import os.log

public enum ProtocolTransportError: Error {
    case unexpectedResponse(AnyJSONRPCResponse)
}

public class ProtocolTransport {
    private typealias DataResult = Result<Data, Error>
    private typealias MessageResponder = (DataResult) -> Void
    public typealias ResponseResult<T: Codable> = Result<JSONRPCResponse<T>, Error>
    public typealias WriteHandler = (Data) throws -> Void

    private var id: Int
    private let queue: DispatchQueue
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var responders: [String: MessageResponder]

    public var responseHandler: ((AnyJSONRPCRequest, Data, @escaping (AnyJSONRPCResponse) -> Void) -> Void)?
    public var notificationHandler: ((AnyJSONRPCNotification, Data, @escaping (Error?) -> Void) -> Void)?
    public var errorHandler: ((Error) -> Void)?
    private let messageTransport: MessageTransport
    private let log: OSLog?
    public var logMessages = false

    public init(messageTransport: MessageTransport) {
        self.messageTransport = messageTransport
        self.id = 1
        self.queue = DispatchQueue(label: "com.chimehq.JSONRPC.ProtocolTransport")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.responders = [:]

        if #available(OSX 10.12, *) {
            self.log = OSLog(subsystem: "com.chimehq.JSONRPC", category: "ProtocolTransport")
        } else {
            self.log = nil
        }

        self.messageTransport.dataHandler = { [unowned self] (data) in
            self.dataAvailable(data)
        }
    }
}

extension ProtocolTransport  {
    public func sendRequest<T, U>(_ params: T, method: String, responseHandler: @escaping (ResponseResult<U>) -> Void) where T: Codable, U: Decodable {
        queue.async {
            let issuedId = self.generateID()

            let request = JSONRPCRequest(id: issuedId, method: method, params: params)

            do {
                try self.encodeAndWrite(request)

                let key = issuedId.description

                precondition(self.responders[key] == nil)

                self.responders[key] = { [unowned self] (result) in
                    self.relayResponse(result: result, responseHandler: responseHandler)
                }
            } catch {
                responseHandler(.failure(error))
            }
        }
    }

    public func sendNotification<T>(_ params: T, method: String, completionHandler: @escaping (Error?) -> Void = {_ in }) where T: Codable {
        let notification = JSONRPCNotification(method: method, params: params)

        queue.async {
            do {
                try self.encodeAndWrite(notification)

                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}

extension ProtocolTransport {
    private func generateID() -> JSONId {
        let issuedId = JSONId.numericId(id)

        id += 1

        return issuedId
    }

    private func encodeAndWrite<T>(_ value: T) throws where T: Codable {
        let data = try self.encoder.encode(value)

        try self.write(data)
    }

    public func dataAvailable(_ data: Data) {
        if logMessages, let string = String(data: data, encoding: .utf8) {
            if #available(OSX 10.12, *), let log = self.log {
                os_log("raw message data %{public}@", log: log, type: .debug, string)
            }
        }

        queue.async {
            // It is important we check for AnyJSONRPCResponse first, as AnyJSONRPCNotification can
            // succesfully decode otherwise

            if let msg = try? self.decoder.decode(AnyJSONRPCResponse.self, from: data) {
                self.dispatchResponse(msg, originalData: data)
                return
            }

            if let note = try? self.decoder.decode(AnyJSONRPCNotification.self, from: data) {
                self.dispatchNotification(note, originalData: data)
                return
            }

            do {
                let request = try self.decoder.decode(AnyJSONRPCRequest.self, from: data)

                self.dispatchRequest(request, originalData: data)
            } catch {
                if #available(OSX 10.12, *), let log = self.log {
                    let string = String(data: data, encoding: .utf8) ?? ""

                    os_log("failed to decode data: %{public}@, %{public}@", log: log, type: .error, error.localizedDescription, string)
                }

                self.errorHandler?(error)
            }
        }
    }

    private func dispatchRequest(_ request: AnyJSONRPCRequest, originalData: Data) {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }

        guard let handler = responseHandler else {
            do {
                let failure = AnyJSONRPCResponse(id: request.id, errorCode: JSONRPCErrors.internalError, message: "No response handler installed")

                try self.encodeAndWrite(failure)
            } catch {
                if #available(OSX 10.12, *), let log = self.log {
                    let string = String(data: originalData, encoding: .utf8) ?? ""

                    os_log("failed to dispatch request: %{public}@, %{public}@", log: log, type: .error, error.localizedDescription, string)
                }

                self.errorHandler?(error)
            }

            return
        }

        handler(request, originalData, { (result) in
            self.queue.async {
                do {
                    try self.encodeAndWrite(result)
                } catch {
                    if #available(OSX 10.12, *), let log = self.log {
                        os_log("dispatch handler failed: %{public}@", log: log, type: .error, error.localizedDescription)
                    }

                    self.errorHandler?(error)
                }
            }
        })

    }
    private func write(_ data: Data) throws {
        messageTransport.write(data)
    }

    private func relayResponse<T>(result: DataResult, responseHandler: @escaping (ResponseResult<T>) -> Void) where T: Decodable {
        switch result {
        case .failure(let error):
            responseHandler(.failure(error))
        case .success(let data):
            queue.async {
                do {
                    let jsonResult = try self.decoder.decode(JSONRPCResponse<T>.self, from: data)

                    responseHandler(.success(jsonResult))
                } catch {
                    responseHandler(.failure(error))
                }
            }
        }
    }

    private func dispatchResponse(_ message: AnyJSONRPCResponse, originalData data: Data) {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }

        let key = message.id.description

        guard let responder = responders[key] else {
            if #available(OSX 10.12, *), let log = self.log {
                os_log("no matching responder for id %{public}@", log: log, type: .error, key)
            }

            errorHandler?(ProtocolTransportError.unexpectedResponse(message))
            return
        }

        responder(.success(data))

        responders.removeValue(forKey: key)
    }

    private func dispatchNotification(_ notification: AnyJSONRPCNotification, originalData data: Data) {
        notificationHandler?(notification, data, { (error) in
            if let error = error {
                if #available(OSX 10.12, *), let log = self.log {
                    os_log("notification handler failed: %{public}@", log: log, type: .error, error.localizedDescription)
                }

                self.errorHandler?(error)
            }
        })
    }
}
