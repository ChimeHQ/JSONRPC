import Foundation
#if !os(Linux)
import OSLog
#endif

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct DataChannel: Sendable {
	public typealias WriteHandler = @Sendable (Data) async throws -> Void
	public typealias DataSequence = AsyncStream<Data>

	public let writeHandler: WriteHandler
	public let dataSequence: DataSequence

	public init(writeHandler: @escaping WriteHandler, dataSequence: DataSequence) {
		self.writeHandler = writeHandler
		self.dataSequence = dataSequence
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension DataChannel {
	public static func transportChannel<Transport: DataTransport>(with transport: Transport) -> DataChannel where Transport: Sendable {
		let framing = SeperatedHTTPHeaderMessageFraming()
		let messageTransport = MessageTransport(dataTransport: transport, messageProtocol: framing)

		let stream = DataSequence { continuation in
			messageTransport.setReaderHandler { data in
				continuation.yield(data)
			}
		}

		return DataChannel(writeHandler: { data in
			transport.write(data)
		}, dataSequence: stream)
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public actor JSONRPCSession {
	public typealias NotificationSequence = AsyncStream<(AnyJSONRPCNotification, Data)>
	public typealias RequestSequence = AsyncStream<(AnyJSONRPCRequest, Data)>
	public typealias DataResult = Result<(AnyJSONRPCResponse, Data), Error>
	private typealias MessageResponder = @Sendable (DataResult) -> Void

	private var id: Int
	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()
	private let channel: DataChannel
	private var readTask: Task<Void, Never>?
	private var notificationContinuation: NotificationSequence.Continuation
	private var requestContinuation: RequestSequence.Continuation
	private var responders = [String: MessageResponder]()

	public let notificationSequence: NotificationSequence
	public let requestSequence: RequestSequence

	public init(channel: DataChannel) {
		self.id = 1
		self.channel = channel

		let notePair = NotificationSequence.makeStream()

		self.notificationSequence = notePair.stream
		self.notificationContinuation = notePair.continuation

		let requestPair = RequestSequence.makeStream()

		self.requestSequence = requestPair.stream
		self.requestContinuation = requestPair.continuation

		Task {
			await startMonitoringChannel()
		}
	}

	deinit {
		readTask?.cancel()

		for (_, responder) in responders {
			responder(.failure(ProtocolTransportError.dataStreamClosed))
		}
	}

	private func generateID() -> JSONId {
		let issuedId = JSONId.numericId(id)

		id += 1

		return issuedId
	}

	private func encodeAndWrite<T>(_ value: T) async throws where T: Encodable {
		let data = try encoder.encode(value)

		try await channel.writeHandler(data)
	}

	private func startMonitoringChannel() {
		precondition(readTask == nil)

		let task = Task { [weak self] in
			guard let channel = self?.channel else { return }

			for await data in channel.dataSequence {
				await self?.handleData(data)
			}
		}

		self.readTask = task
	}

	private func handleData(_ data: Data) {
		do {
			try self.decodeAndDispatch(data: data)
		} catch {
			print("unable to process data: \(error)")
		}
	}

	private func decodeAndDispatch(data: Data) throws {
		let msg = try decoder.decode(JSONRPCMessage.self, from: data)

		switch msg {
		case .notification(let method, let params):
			let note = AnyJSONRPCNotification(method: method, params: params)

			notificationContinuation.yield((note, data))
		case .response(let id):
			let resp = AnyJSONRPCResponse(id: id, result: nil)

			try dispatchResponse(resp, originalData: data)
		case .request(let id, let method, let params):
			let req = AnyJSONRPCRequest(id: id, method: method, params: params)

			requestContinuation.yield((req, data))
		case .undecodableId(let error):
			print("failed to decode: \(error)")
		}
	}

	private func dispatchResponse(_ message: AnyJSONRPCResponse, originalData data: Data) throws {
		let key = message.id.description

		guard let responder = responders[key] else {
			throw ProtocolTransportError.unexpectedResponse(data)
		}

		responder(.success((message, data)))

		responders[key] = nil
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension JSONRPCSession {
	public func sendDataRequest<Request>(_ params: Request, method: String) async throws -> (AnyJSONRPCResponse, Data)
	where Request: Encodable {
		return try await withCheckedThrowingContinuation({ continuation in
			// make sure not to capture self
			self.sendDataRequest(params, method: method) { [weak self] result in
				guard self != nil else {
					continuation.resume(throwing: ProtocolTransportError.abandonedRequest)
					return
				}

				continuation.resume(with: result)
			}
		})
	}

	public func sendRequest<Request, Response>(_ params: Request, method: String) async throws -> JSONRPCResponse<Response>
	where Request: Encodable, Response: Decodable {
		let (_, data) = try await sendDataRequest(params, method: method)

		return try decoder.decode(JSONRPCResponse<Response>.self, from: data)
	}

	public func sendNotification<Note>(_ params: Note?, method: String) async throws where Note: Encodable {
		let notification = JSONRPCNotification(method: method, params: params)
		
		try await encodeAndWrite(notification)
	}
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension JSONRPCSession {
	private func sendDataRequest<Request>(_ params: Request, method: String, responseHandler: @escaping MessageResponder)
	where Request: Encodable {
		let issuedId = generateID()

		let request = JSONRPCRequest(id: issuedId, method: method, params: params)

		Task {
			do {
				try await encodeAndWrite(request)
			} catch {
				responseHandler(.failure(error))
				return
			}
			
			let key = issuedId.description
			
			precondition(responders[key] == nil)
			
			self.responders[key] = responseHandler
		}
	}
}
