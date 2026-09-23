import SwiftUI

struct GameListView: View {
    let server: LocalHTTPServer

    @State private var games: [GameInfo] = []
    @State private var searchText = ""
    @State private var selectedCategory = "すべて"

    private var categories: [String] {
        ["すべて"] + Set(games.map(\.category)).sorted()
    }

    private var filteredGames: [GameInfo] {
        games.filter { game in
            (selectedCategory == "すべて" || game.category == selectedCategory) &&
            (searchText.isEmpty || game.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredGames) { game in
                NavigationLink(value: game) {
                    VStack(alignment: .leading) {
                        Text(game.title).font(.headline)
                        Text(game.category).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "ゲームを検索...")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Offline Games")
            .navigationDestination(for: GameInfo.self) { game in
                GameWebView(url: URL(string: "http://127.0.0.1:\(server.port)\(game.relativePath)")!)
                    .navigationTitle(game.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear(perform: reload)
            .refreshable { reload() }
        }
    }

    private func reload() {
        let gamesRoot = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("games")
        games = GameLibraryScanner.scan(gamesRoot: gamesRoot)
    }
}
