import Foundation
#if !os(Linux)
import os.log
#endif

public enum ProtocolTransportError: Error {
    case undecodableMesssage(Data)
    case unexpectedResponse(Data)
    case abandonedRequest
    case dataStreamClosed
}

@available(*, deprecated, message: "Please migrate to JSONRPCSession")
public class ProtocolTransport: @unchecked Sendable {
	public struct Handlers {
		public typealias RequestHandler = (AnyJSONRPCRequest, Data, @escaping (AnyJSONRPCResponse) -> Void) -> Void
		public typealias NotificationHandler = (AnyJSONRPCNotification, Data, @escaping (Error?) -> Void) -> Void
		public typealias ErrorHandler = (Error) -> Void

		public let request: RequestHandler?
		public let notification: NotificationHandler?
		public let error: ErrorHandler?

		public init(request: RequestHandler?, notification: NotificationHandler?, error: ErrorHandler?) {
			self.request = request
			self.notification = notification
			self.error = error
		}
	}

    public typealias DataResult = Result<(AnyJSONRPCResponse, Data), Error>
    private typealias MessageResponder = (DataResult) -> Void
    public typealias ResponseResult<T: Decodable> = Result<JSONRPCResponse<T>, Error>

    private var id: Int
    private let queue: DispatchQueue
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var responders: [String: MessageResponder]
	private var handlers = Handlers(request: nil, notification: nil, error: nil)
    private let dataTransport: DataTransport
    #if !os(Linux)
    private let log: OSLog
    #endif
    public var logMessages = false

    public init(dataTransport: DataTransport) {
        self.dataTransport = dataTransport
        self.id = 1
        self.queue = DispatchQueue(label: "com.chimehq.JSONRPC.ProtocolTransport")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.responders = [:]
        #if !os(Linux)
        self.log = OSLog(subsystem: "com.chimehq.JSONRPC", category: "ProtocolTransport")
        #endif

        dataTransport.setReaderHandler({ [unowned self] (data) in
            self.dataAvailable(data)
        })
    }

    deinit {
        for (_, responder) in responders {
            responder(.failure(ProtocolTransportError.dataStreamClosed))
        }
    }

	/// Install functions to handle requests, notifications, and errors.
	public func setHandlers(_ handlers: Handlers) {
		queue.async {
			self.handlers = handlers
		}
	}
}

@available(*, deprecated, message: "Please migrate to JSONRPCSession")
extension ProtocolTransport  {
	public func sendDataRequest<T>(_ params: T, method: String, responseHandler: @escaping (DataResult) -> Void) where T: Encodable {
		queue.async {
			let issuedId = self.generateID()

			let request = JSONRPCRequest(id: issuedId, method: method, params: params)

			do {
				try self.encodeAndWrite(request)
			} catch {
				responseHandler(.failure(error))
				return
			}

			let key = issuedId.description

			precondition(self.responders[key] == nil)

			self.responders[key] = { (result) in
				responseHandler(result)
			}
		}
	}

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	public func sendDataRequest<T>(_ params: T, method: String) async throws -> (AnyJSONRPCResponse, Data) where T: Encodable {
		return try await withCheckedThrowingContinuation({ continuation in
			self.sendDataRequest(params, method: method) { result in
				continuation.resume(with: result)
			}
		})
	}

	public func sendRequest<T, U>(_ params: T, method: String, responseHandler: @escaping (ResponseResult<U>) -> Void) where T: Encodable, U: Decodable {
		sendDataRequest(params, method: method) { [weak self] (result) in
			guard let self = self else {
				responseHandler(.failure(ProtocolTransportError.abandonedRequest))
				return
			}

			self.relayResponse(result: result, responseHandler: responseHandler)
		}
    }

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	public func sendRequest<T, U>(_ params: T, method: String) async throws -> JSONRPCResponse<U> where T: Encodable, U: Decodable {
		return try await withCheckedThrowingContinuation({ continuation in
			self.sendRequest(params, method: method) { result in
				continuation.resume(with: result)
			}
		})
	}

    public func sendNotification<T>(_ params: T?, method: String, completionHandler: @escaping (Error?) -> Void = {_ in }) where T: Encodable {
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

	@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
	public func sendNotification<T>(_ params: T?, method: String) async throws where T: Encodable {
		try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) in
			self.sendNotification(params, method: method) { result in
				switch result {
				case .none:
					continuation.resume()
				case let error?:
					continuation.resume(throwing: error)
				}
			}
		})
	}
}

@available(*, deprecated, message: "Please migrate to JSONRPCSession")
extension ProtocolTransport {
    private func generateID() -> JSONId {
        let issuedId = JSONId.numericId(id)

        id += 1

        return issuedId
    }

    private func encodeAndWrite<T>(_ value: T) throws where T: Encodable {
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

				self.handlers.error?(error)
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

		guard let handler = self.handlers.request else {
			let error = AnyJSONRPCResponseError(code: JSONRPCErrors.internalError, message: "No response handler installed")
			let failure = AnyJSONRPCResponse(id: request.id, content: .failure(error))

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

					self.handlers.error?(error)
                }
            }
        })

    }
    private func write(_ data: Data) throws {
        dataTransport.write(data)
    }

    private func relayResponse<T>(result: DataResult, responseHandler: @escaping (ResponseResult<T>) -> Void) where T: Decodable {
        switch result {
        case .failure(let error):
            responseHandler(.failure(error))
		case .success((_, let data)):
            do {
                let jsonResult = try self.decoder.decode(JSONRPCResponse<T>.self, from: data)

                responseHandler(.success(jsonResult))
            } catch {
                responseHandler(.failure(error))
            }
        }
    }

    private func dispatchResponse(_ message: AnyJSONRPCResponse, originalData data: Data) throws {
        dispatchPrecondition(condition: .onQueue(queue))

        let key = message.id.description

        guard let responder = responders[key] else {
            throw ProtocolTransportError.unexpectedResponse(data)
        }

        responder(.success((message, data)))

        responders.removeValue(forKey: key)
    }

    private func dispatchNotification(_ notification: AnyJSONRPCNotification, originalData data: Data) {
		self.handlers.notification?(notification, data, { (error) in
            if let error = error {
                #if os(Linux)
                print("notification handler failed: \(error)")
                #else
                os_log("notification handler failed: %{public}@", log: self.log, type: .error, String(describing: error))
                #endif

				self.queue.async {
					self.handlers.error?(error)
				}
            }
        })
    }
}
