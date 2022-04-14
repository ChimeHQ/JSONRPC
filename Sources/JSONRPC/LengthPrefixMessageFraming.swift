import Foundation

public struct LengthPrefixMessageFraming {
    public let lengthTerminator: Data
    public let contentTerminator: Data
    private let paddingCount = 8

    public init(lengthTerminator: String = "\n", contentTerminator: String = "\n") {
        self.lengthTerminator = lengthTerminator.data(using: .utf8)!
        self.contentTerminator = contentTerminator.data(using: .utf8)!
    }
}

extension LengthPrefixMessageFraming: MessageFraming {
    public func nextMessageRange(in data: Data) -> Range<Data.Index>? {
        let minimumSize = paddingCount + lengthTerminator.count + contentTerminator.count

        if data.count < minimumSize {
            return nil
        }

        let lengthData = data[0..<paddingCount]
        guard let lengthString = String(data: lengthData, encoding: .utf8) else {
            return nil
        }

        guard let length = Int(lengthString, radix: 16) else {
            return nil
        }

        let start = data.startIndex + paddingCount + lengthTerminator.count
        let end = start + length + contentTerminator.count

        if end > data.endIndex {
            return nil
        }

        return start..<end
    }

    public func frameData(_ data: Data) -> Data {
        let length = data.count

        guard let hex = String(length, radix: 16, uppercase: true).data(using: .utf8) else {
            return Data()
        }

        let padCount = paddingCount - hex.count

        precondition(padCount >= 0)

        // padding is ascii 0, 48
        let padding = Data(repeating: 48, count: padCount)

        return padding + hex + lengthTerminator + data + contentTerminator
    }
}
