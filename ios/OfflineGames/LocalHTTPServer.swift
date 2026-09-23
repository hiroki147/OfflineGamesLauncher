import Foundation
import Network

/// Documents/games/ 以下を配信する、依存ライブラリ不要の最小HTTPサーバー。
/// GETのみ対応(静的ファイル配信専用なのでこれで十分)。
final class LocalHTTPServer {
    private var listener: NWListener?
    let port: UInt16
    let documentRoot: URL

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
            sendResponse(status: "405 Method Not Allowed", body: Data(), contentType: "text/plain", on: connection)
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
            sendResponse(status: "403 Forbidden", body: Data(), contentType: "text/plain", on: connection)
            return
        }

        if let data = try? Data(contentsOf: fileURL) {
            sendResponse(status: "200 OK", body: data, contentType: mimeType(for: fileURL), on: connection)
        } else {
            sendResponse(status: "404 Not Found", body: Data("Not Found".utf8), contentType: "text/plain", on: connection)
        }
    }

    private func sendResponse(status: String, body: Data, contentType: String, on connection: NWConnection) {
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
        case "wasm": return "application/wasm"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
