import Foundation
import JSONRPC

final class MockDataTransport: DataTransport {
    var writtenData: [Data]
    var readHandler: ReadHandler?

    init() {
        self.writtenData = []
        self.readHandler = nil
    }

    func write(_ data: Data) {
        writtenData.append(data)
    }

    func setReaderHandler(_ handler: @escaping ReadHandler) {
        readHandler = handler
    }

    func close() {
    }

    func mockRead(_ data: Data) {
        self.readHandler?(data)
    }

    func mockRead(_ string: String) {
        mockRead(string.data(using: .utf8)!)
    }
}
