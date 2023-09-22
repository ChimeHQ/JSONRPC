import XCTest
@testable import JSONRPC

final class DataChannelTests: XCTestCase {
	func testEmptyChannelBlocking() async throws {
		let channel = DataActor(queue: Array())

		let receiveTask = Task {
			let receivedData = await channel.recv()
			return String(data: receivedData, encoding: .utf8)!
		}

		// try await Task.sleep(for: Duration.seconds(0.05))
		while await channel.numBlocked == 0 {
			continue
		}

		let msg = "hello"
		await channel.send(msg.data(using: .utf8)!)
		let receivedMsg = await receiveTask.result
		XCTAssertEqual(msg, try receivedMsg.get())

		await channel.send(msg.data(using: .utf8)!)

		let numSent = await channel.numSent
		let numReceived = await channel.numReceived
		let numBlocked = await channel.numBlocked
		let queueCount = await channel.queueCount

		XCTAssertEqual(numSent, 2)
		XCTAssertEqual(numReceived, 1)
		XCTAssertEqual(numBlocked, 1)
		XCTAssertEqual(queueCount, 1)
	}

	func testBidirectionalChannel() async throws {
		let (clientChannel, serverChannel) = DataChannel.withDataActor()
		let msg = "hello"
		try await clientChannel.writeHandler(msg.data(using: .utf8)!)
		var it = serverChannel.dataSequence.makeAsyncIterator();
		let receivedData = await it.next()
		let receivedMsg = String(data: receivedData!, encoding: .utf8)!
		XCTAssertEqual(msg, receivedMsg)

	}

	func testSimpleRPC() {
		let (_, serverChannel) = DataChannel.withDataActor()
		let _ = JSONRPCSession(channel: serverChannel)
		// TODO...
	}
}
