import SwiftUI

@main
struct OfflineGamesApp: App {
    private let server: LocalHTTPServer

    init() {
        let gamesRoot = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games")

        try? FileManager.default.createDirectory(at: gamesRoot, withIntermediateDirectories: true)

        server = LocalHTTPServer(port: 8080, documentRoot: gamesRoot)
        server.start()
    }

    var body: some Scene {
        WindowGroup {
            GameListView(server: server)
        }
    }
}
