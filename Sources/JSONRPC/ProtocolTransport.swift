import Foundation
#if !os(Linux)
import os.log
#endif

public enum ProtocolTransportError: Error {
    case undecodableMesssage(Data)
    case unexpectedResponse(AnyJSONRPCResponse)
    case abandonedRequest
    case dataStreamClosed
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
    #if !os(Linux)
    private let log: OSLog
    #endif
    public var logMessages = false

    public init(messageTransport: MessageTransport) {
        self.messageTransport = messageTransport
        self.id = 1
        self.queue = DispatchQueue(label: "com.chimehq.JSONRPC.ProtocolTransport")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.responders = [:]
        #if !os(Linux)
        self.log = OSLog(subsystem: "com.chimehq.JSONRPC", category: "ProtocolTransport")
        #endif

        self.messageTransport.dataHandler = { [unowned self] (data) in
            self.dataAvailable(data)
        }
    }

    deinit {
        for (_, responder) in responders {
            responder(.failure(ProtocolTransportError.dataStreamClosed))
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

                self.responders[key] = { [weak self] (result) in
                    guard let self = self else {
                        responseHandler(.failure(ProtocolTransportError.abandonedRequest))
                        return
                    }

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
            #if os(Linux)
            print("sending: \(string)")
            #else
            os_log("sending: %{public}@", log: log, type: .debug, string)
            #endif
        }

        try self.write(data)
    }

    public func dataAvailable(_ data: Data) {
        if logMessages, let string = String(data: data, encoding: .utf8) {
            #if os(Linux)
            print("received: \(string)")
            #else
            os_log("received: %{public}@", log: log, type: .debug, string)
            #endif
        }

        queue.async {
            do {
                try self.decodeAndDispatch(data: data)
            } catch {
                let string = String(data: data, encoding: .utf8) ?? ""

                #if os(Linux)
                print("failed to decode data: \(error), \(string)")
                #else
                os_log("failed to decode data: %{public}@, %{public}@", log: self.log, type: .error, String(describing: error), string)
                #endif

                self.errorHandler?(error)
            }
        }
    }

    private func decodeAndDispatch(data: Data) throws {
        let msg = try decoder.decode(JSONRPCMessage.self, from: data)

        switch msg {
        case .notification(let method, let params):
            let note = AnyJSONRPCNotification(method: method, params: params)

            dispatchNotification(note, originalData: data)
        case .response(let id):
            let resp = AnyJSONRPCResponse(id: id, result: nil)

            try dispatchResponse(resp, originalData: data)
        case .request(let id, let method, let params):
            let req = AnyJSONRPCRequest(id: id, method: method, params: params)

            try dispatchRequest(req, originalData: data)
        case .undecodableId(let error):
            #if os(Linux)
            print("sender reported undecodable id: ", String(describing: error))
            #else
            os_log("sender reported undecodable id: %{public}@", log: self.log, type: .error, String(describing: error))
            #endif
        }
    }

    private func dispatchRequest(_ request: AnyJSONRPCRequest, originalData: Data) throws {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
            dispatchPrecondition(condition: .onQueue(queue))
        }

        guard let handler = requestHandler else {
            let failure = AnyJSONRPCResponse.internalError(id: request.id,
                                                        message: "No response handler installed")

            try self.encodeAndWrite(failure)

            return
        }

        handler(request, originalData, { (result) in
            self.queue.async {
                do {
                    try self.encodeAndWrite(result)
                } catch {
                    #if os(Linux)
                    print("dispatch handler failed: \(error)")
                    #else
                    os_log("dispatch handler failed: %{public}@", log: self.log, type: .error, String(describing: error))
                    #endif

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
        dispatchPrecondition(condition: .onQueue(queue))

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
                #if os(Linux)
                print("notification handler failed: \(error)")
                #else
                os_log("notification handler failed: %{public}@", log: self.log, type: .error, String(describing: error))
                #endif

                self.errorHandler?(error)
            }
        })
    }
}
