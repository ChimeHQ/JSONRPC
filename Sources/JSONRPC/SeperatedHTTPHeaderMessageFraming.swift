import Foundation

/// A concrete `MessageFraming` implemenation that uses HTTP headers.
///
/// It requires at least `Content-Length`, and by default expects all fields to be separated by `\r\n`.
@available(*, deprecated, message: "Please migrate to JSONRPCSession")
public struct SeperatedHTTPHeaderMessageFraming {
    private let partSeperator: Data
    private let contentSeperator: Data
    private let headerComponentSeperator = ": ".data(using: .utf8) ?? Data()
    private let fullSeperator: Data

    public init(partSeperator: String = "\r\n", contentSeperator: String = "\r\n") {
        self.partSeperator = partSeperator.data(using: .utf8)!
        self.contentSeperator = contentSeperator.data(using: .utf8)!

        // this is just a tiny optimization, since we'll use it so much
        self.fullSeperator = self.partSeperator + self.contentSeperator
    }

    private func readHeader(in data: Data, range: Range<Data.Index>) -> (String, String, Data.Index)? {
        guard let seperatorRange = data.range(of: headerComponentSeperator, options: [], in: range) else {
            return nil
        }

        let keyRange = range.lowerBound..<seperatorRange.lowerBound
        let postSeperatorRange = seperatorRange.upperBound..<range.upperBound

        let terminatorRange = data.range(of: partSeperator, options: [], in: postSeperatorRange)
        let valueUpperBound = terminatorRange?.lowerBound ?? range.upperBound
        let valueRange = postSeperatorRange.lowerBound..<valueUpperBound

        let keyData = data.subdata(in: keyRange)
        let valueData = data.subdata(in: valueRange)

        guard let key = String(data: keyData, encoding: .utf8) else {
            return nil
        }

        guard let value = String(data: valueData, encoding: .utf8) else {
            return nil
        }

        let endOfHeader = terminatorRange?.upperBound ?? range.upperBound

        return (key, value, endOfHeader)
    }

    private func readHeaders(from data: Data, in range: Range<Data.Index>) -> [String: String] {
        var headers: [String: String] = [:]

        var location = range.lowerBound

        while location < range.upperBound {
            let searchRange = location..<range.upperBound

            guard let headerData = readHeader(in: data, range: searchRange) else {
                break
            }

            let (key, value, limit) = headerData

            headers[key] = value

            location = limit
        }

        return headers
    }
}

extension SeperatedHTTPHeaderMessageFraming: MessageFraming {
    public func nextMessageRange(in data: Data) -> Range<Data.Index>? {
        guard let range = data.range(of: fullSeperator) else {
            return nil
        }

        let headersSectionRange = data.startIndex..<range.lowerBound

        let headers = readHeaders(from: data, in: headersSectionRange)

        guard let lengthValue = headers["Content-Length"] else {
            return nil
        }

        guard let length = Int(lengthValue) else {
            return nil
        }

        let upperLimit = length + range.upperBound
        if upperLimit > data.endIndex {
            return nil
        }

        return range.upperBound..<upperLimit
    }

    public func frameData(_ data: Data) -> Data {
        let length = data.count

        let header = "Content-Length: \(length)"
        guard let headerData = header.data(using: .utf8) else {
            fatalError()
        }

        return headerData + fullSeperator + data
    }
}
