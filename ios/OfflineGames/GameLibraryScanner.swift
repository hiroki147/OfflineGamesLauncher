import Foundation

struct GameInfo: Identifiable, Hashable {
    let id: String            // フォルダ名
    let title: String
    let category: String
    let relativePath: String  // games/ 以下、index.htmlまでの相対パス
}

/// Documents/games/ を再帰的に走査し、index.htmlがあるフォルダをゲームとして扱う。
/// game.json があれば title / category を上書きする(なければフォルダ名 / "HTML5"にフォールバック)。
enum GameLibraryScanner {
    static func scan(gamesRoot: URL) -> [GameInfo] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: gamesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var games: [GameInfo] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.lowercased() == "index.html" else { continue }

            let folderURL = fileURL.deletingLastPathComponent()
            let folderName = folderURL.lastPathComponent
            let relativePath = fileURL.path.replacingOccurrences(of: gamesRoot.path, with: "")

            var title = folderName
            var category = "HTML5"

            let jsonURL = folderURL.appendingPathComponent("game.json")
            if let data = try? Data(contentsOf: jsonURL),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                title = obj["title"] as? String ?? title
                category = obj["category"] as? String ?? category
            }

            games.append(GameInfo(
                id: folderName,
                title: title,
                category: category,
                relativePath: relativePath
            ))
        }

        return games.sorted { $0.title < $1.title }
    }
}
