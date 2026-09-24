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

        // iOSでは /var/... が /private/var/... へのシンボリックリンクになっており、
        // enumerator が返すパスとルートパスで解決状態が食い違うことがあるため、
        // 差し引き計算の前に両方ともシンボリックリンク解決済みの形に揃える。
        let resolvedRoot = gamesRoot.resolvingSymlinksInPath()

        guard let enumerator = fm.enumerator(
            at: gamesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var games: [GameInfo] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.lowercased() == "index.html" else { continue }

            let resolvedFileURL = fileURL.resolvingSymlinksInPath()

            let folderURL = fileURL.deletingLastPathComponent()
            let folderName = folderURL.lastPathComponent

            var relativePath = resolvedFileURL.path.replacingOccurrences(
                of: resolvedRoot.path,
                with: ""
            )
            if !relativePath.hasPrefix("/") {
                relativePath = "/" + relativePath
            }

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
