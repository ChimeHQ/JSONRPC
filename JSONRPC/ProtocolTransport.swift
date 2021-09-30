import Foundation
import os.log

public enum ProtocolTransportError: Error {
    case undecodableMesssage(Data)
    case unexpectedResponse(AnyJSONRPCResponse)
    case abandonedRequest
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

    public var requestHandler: ((AnyJSONRPCRequest, Data, @escaping (AnyJSONRPCResponse) -> Void) -> Void)?
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

    deinit {
        for (_, responder) in responders {
            responder(.failure(ProtocolTransportError.abandonedRequest))
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

    public func sendNotification<T>(_ params: T?, method: String, completionHandler: @escaping (Error?) -> Void = {_ in }) where T: Codable {
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

        if logMessages, let string = String(data: data, encoding: .utf8) {
            if #available(OSX 10.12, *), let log = self.log {
                os_log("sending: %{public}@", log: log, type: .debug, string)
            }
        }

        try self.write(data)
    }

    public func dataAvailable(_ data: Data) {
        if logMessages, let string = String(data: data, encoding: .utf8) {
            if #available(OSX 10.12, *), let log = self.log {
                os_log("received: %{public}@", log: log, type: .debug, string)
            }
        }

        queue.async {
            do {
                try self.decodeAndDispatch(data: data)
            } catch {
                if #available(OSX 10.12, *), let log = self.log {
                    let string = String(data: data, encoding: .utf8) ?? ""

                    os_log("failed to decode data: %{public}@, %{public}@", log: log, type: .error, error.localizedDescription, string)
                }

                self.errorHandler?(error)
            }
        }
    }

    private func decodeAndDispatch(data: Data) throws {
        // Decoding correctly is a challange. The message forms have a lot of optional attributes, which
        // makes them indistinguishable from Codable's perspective. The solution I came up with is to
        // decode a generic "message" type, and then inspect the non-null properties to determine the actual
        // message struct.

        let msg = try decoder.decode(JSONRPCMessage.self, from: data)

        switch msg.kind {
        case .invalid:
            throw ProtocolTransportError.undecodableMesssage(data)
        case .notification:
            let note = try decoder.decode(AnyJSONRPCNotification.self, from: data)

            dispatchNotification(note, originalData: data)
        case .response:
            let rsp = try decoder.decode(AnyJSONRPCResponse.self, from: data)

            try dispatchResponse(rsp, originalData: data)
        case .request:
            let request = try decoder.decode(AnyJSONRPCRequest.self, from: data)

            try dispatchRequest(request, originalData: data)
        }
    }

    private func dispatchRequest(_ request: AnyJSONRPCRequest, originalData: Data) throws {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }

        guard let handler = requestHandler else {
            let failure = AnyJSONRPCResponse(id: request.id,
                                             errorCode: JSONRPCErrors.internalError,
                                             message: "No response handler installed")

            try self.encodeAndWrite(failure)

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

    private func dispatchResponse(_ message: AnyJSONRPCResponse, originalData data: Data) throws {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }

        let key = message.id.description

        guard let responder = responders[key] else {
            throw ProtocolTransportError.unexpectedResponse(message)
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
