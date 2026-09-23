import Foundation
import Network

/// Documents/games/ 以下を配信する、依存ライブラリ不要の最小HTTPサーバー。
/// GETのみ対応(静的ファイル配信専用なのでこれで十分)。
/// 大きなファイル(tar.gz等)も一括ロードせず、チャンク単位でストリーミング送信する。
final class LocalHTTPServer {
    private var listener: NWListener?
    let port: UInt16
    let documentRoot: URL

    private let chunkSize = 256 * 1024

    init(port: UInt16 = 8080, documentRoot: URL) {
        self.port = port
        self.documentRoot = documentRoot
    }

    func start() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        listener = try? NWListener(using: .tcp, on: nwPort)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.respond(to: data, on: connection)
            }
            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private func respond(to requestData: Data, on connection: NWConnection) {
        guard let requestString = String(data: requestData, encoding: .utf8),
              let requestLine = requestString.split(separator: "\r\n").first else {
            connection.cancel()
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendSimpleResponse(status: "405 Method Not Allowed", body: Data(), contentType: "text/plain", on: connection)
            return
        }

        var path = String(parts[1])
        if let query = path.firstIndex(of: "?") {
            path = String(path[path.startIndex..<query])
        }
        path = path.removingPercentEncoding ?? path
        if path == "/" { path = "/index.html" }

        let fileURL = documentRoot.appendingPathComponent(path)

        // Documents/games/ の外を読ませないためのガード
        let standardizedRoot = documentRoot.standardizedFileURL.path
        let standardizedFile = fileURL.standardizedFileURL.path
        guard standardizedFile.hasPrefix(standardizedRoot) else {
            sendSimpleResponse(status: "403 Forbidden", body: Data(), contentType: "text/plain", on: connection)
            return
        }

        sendFileResponse(fileURL: fileURL, on: connection)
    }

    /// ファイルをストリーミングで返す。まるごとメモリに載せない。
    private func sendFileResponse(fileURL: URL, on connection: NWConnection) {
        let fm = FileManager.default

        guard fm.fileExists(atPath: fileURL.path) else {
            print("404: no such file at \(fileURL.path)")
            sendSimpleResponse(status: "404 Not Found", body: Data("Not Found".utf8), contentType: "text/plain", on: connection)
            return
        }

        guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
              let fileSize = attrs[.size] as? Int else {
            print("500: failed to stat \(fileURL.path)")
            sendSimpleResponse(status: "500 Internal Server Error", body: Data("Failed to stat file".utf8), contentType: "text/plain", on: connection)
            return
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            print("500: failed to open \(fileURL.path)")
            sendSimpleResponse(status: "500 Internal Server Error", body: Data("Failed to open file".utf8), contentType: "text/plain", on: connection)
            return
        }

        let header =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: \(mimeType(for: fileURL))\r\n" +
            "Content-Length: \(fileSize)\r\n" +
            "Connection: close\r\n\r\n"

        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                print("header send error: \(error)")
                fileHandle.closeFile()
                connection.cancel()
                return
            }
            self.streamChunk(fileHandle: fileHandle, connection: connection)
        })
    }

    private func streamChunk(fileHandle: FileHandle, connection: NWConnection) {
        let data = fileHandle.readData(ofLength: chunkSize)

        if data.isEmpty {
            fileHandle.closeFile()
            connection.cancel()
            return
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                print("chunk send error: \(error)")
                fileHandle.closeFile()
                connection.cancel()
                return
            }
            self.streamChunk(fileHandle: fileHandle, connection: connection)
        })
    }

    private func sendSimpleResponse(status: String, body: Data, contentType: String, on connection: NWConnection) {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"

        var response = Data(header.utf8)
        response.append(body)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css": return "text/css"
        case "js", "mjs": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "wav": return "audio/wav"
        case "gz": return "application/gzip"
        case "tar": return "application/x-tar"
        case "wasm": return "application/wasm"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
