import Foundation

public protocol DataTransport {
    typealias ReadHandler = (Data) -> Void

    func write(_ data: Data)
    func setReaderHandler(_ handler: @escaping ReadHandler)

    func close()
}
