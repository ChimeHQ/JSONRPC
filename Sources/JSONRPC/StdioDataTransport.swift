import Foundation
#if !os(Linux)
import os.log
#endif

public class StdioDataTransport: DataTransport, @unchecked Sendable {
    public let stdinPipe: Pipe
    public let stdoutPipe: Pipe
    public let stderrPipe: Pipe
    var readHandler: ReadHandler?
    private var closed: Bool
    private var queue: DispatchQueue
    #if !os(Linux)
    private let log: OSLog
    #endif

    public init() {
        self.stdinPipe = Pipe()
        self.stdoutPipe = Pipe()
        self.stderrPipe = Pipe()
        self.readHandler = nil
        self.closed = false
        self.queue = DispatchQueue(label: "com.chimehq.JSONRPC.StdioDataTransport")
        #if !os(Linux)
        self.log = OSLog(subsystem: "com.chimehq.JSONRPC", category: "StdioDataTransport")
        #endif

        setupFileHandleHandlers()
    }

    public func write(_ data: Data) {
        if closed {
            return
        }

        let fileHandle = self.stdinPipe.fileHandleForWriting

        self.queue.async {
            fileHandle.write(data)
        }
    }

    public func setReaderHandler(_ handler: @escaping (Data) -> Void) {
        queue.sync { [unowned self] in
            self.readHandler = handler
        }
    }

    public func close() {
        queue.sync {
            if self.closed {
                return
            }

            self.closed = true

            [stdoutPipe, stderrPipe, stdinPipe].forEach { (pipe) in
                pipe.fileHandleForWriting.closeFile()
                pipe.fileHandleForReading.closeFile()
            }
        }
    }

    private func setupFileHandleHandlers() {
        stdoutPipe.fileHandleForReading.readabilityHandler = { [unowned self] (handle) in
            let data = handle.availableData

            guard data.count > 0 else {
                return
            }

            self.forwardDataToHandler(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [unowned self] (handle) in
            let data = handle.availableData

            guard data.count > 0 else {
                return
            }

            self.forwardErrorDataToHandler(data)
        }
    }

    private func forwardDataToHandler(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.closed {
                return
            }

            self.readHandler?(data)
        }
    }

    private func forwardErrorDataToHandler(_ data: Data) {
        queue.async { [weak self] in
            // Just print for now. Perhaps provide a way to hook
            // this up to a caller?
            if let string = String(bytes: data, encoding: .utf8) {
                #if os(Linux)
                print("stderr: \(string)")
                #else
                if let log = self?.log {
                    os_log("stderr: %{public}@", log: log, type: .error, string)
                } else {
                    print("stderr: \(string)")
                }
                #endif
            }
        }
    }
}

