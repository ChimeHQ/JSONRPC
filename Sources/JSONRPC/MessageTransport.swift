import Foundation

public protocol MessageFraming {
    func nextMessageRange(in data: Data) -> Range<Data.Index>?
    func frameData(_ data: Data) -> Data
}

public class MessageTransport {
    private let dataTransport: DataTransport
    private var buffer: Data
    private let messageProtocol: MessageFraming

    public var dataHandler: DataTransport.ReadHandler?

    public init(dataTransport: DataTransport, messageProtocol: MessageFraming) {
        self.dataTransport = dataTransport
        self.messageProtocol = messageProtocol

        self.buffer = Data()

        setupReadHandler()
    }

    private func setupReadHandler() {
        dataTransport.setReaderHandler({ [unowned self] (data) in
            guard data.count > 0 else {
                return
            }

            self.dataReceived(data)
        })
    }

    private func dataReceived(_ data: Data) {
        buffer.append(data)

        checkBuffer()
    }

    private func checkBuffer() {
        guard let contentRange = messageProtocol.nextMessageRange(in: buffer) else {
            return
        }

        if buffer.endIndex < contentRange.upperBound {
            return
        }

        let content = buffer.subdata(in: contentRange)
        let messageRange = buffer.startIndex..<contentRange.upperBound

        precondition(messageRange.count > 0)

        buffer.removeSubrange(messageRange)

        self.dataHandler?(content)

        // call recursively *only* if we have removed some data
        if !buffer.isEmpty {
            checkBuffer()
        }
    }
}

extension MessageTransport: DataTransport {
    public func write(_ data: Data) {
        let messageData = messageProtocol.frameData(data)

        dataTransport.write(messageData)
    }

    public func setReaderHandler(_ handler: @escaping DataTransport.ReadHandler) {
        self.dataHandler = handler
    }

    public func close() {
        dataTransport.close()
    }
}
