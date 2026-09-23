# Offline Games Launcher — セットアップ手順

Macは不要です。プロジェクトの生成・ビルドはすべてGitHub Actions(macOSランナー)上で行います。

## 1. リポジトリにpush

このフォルダの中身をそのままGitHubリポジトリにpushしてください。

```
cd OfflineGamesLauncher
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/ユーザー名/リポジトリ名.git
git push -u origin main
```

## 2. GitHub Actionsが自動実行

`ios/**` に変更がある状態でpushすると `.github/workflows/build.yml` が動き、以下を自動で行います。

1. Homebrewで `xcodegen` をインストール
2. `ios/project.yml` から `OfflineGames.xcodeproj` を生成
3. 署名なしでビルド(`CODE_SIGNING_ALLOWED=NO`)
4. `OfflineGames.ipa` を作成し、Artifactsにアップロード

Actionsタブから手動実行(workflow_dispatch)もできます。
ビルドが終わったら、リポジトリの Actions > 該当の実行 > Artifacts から `OfflineGames-ipa` をダウンロードしてください(中に `OfflineGames.ipa` が入っています)。

## 3. SideStoreでインストール

1. ダウンロードした `OfflineGames.ipa` をiPhoneに転送(AirDrop、iCloud Drive経由など)
2. SideStoreで「Import」し、SideStoreが自動で署名してインストール
3. 7日ごとの再署名は、SideServerとのWi-Fi内バックグラウンドリフレッシュ、
   またはPCのAltServer/SideStoreヘルパーとの定期接続で自動化してください

## 4. ゲームデータの転送(Filesアプリ経由)

1. iPhoneのFilesアプリを開く
2. 「このiPhone内」の「OfflineGames」フォルダを開く(→ `Documents/games/`)
3. 既存のゲームフォルダ(index.html + assets 一式)をそのままドラッグ&ドロップ

フォルダ構成はそのままでOKです。`index.html` があるフォルダが自動的に1ゲームとして
一覧に表示されます。`game.json` を置くとタイトル/カテゴリを上書きできます。

```json
{
  "title": "ゲームのタイトル",
  "category": "HTML5"
}
```

## ファイル構成

```
OfflineGamesLauncher/
├── ios/
│   ├── project.yml          ← XcodeGen定義(これから.xcodeprojが生成される)
│   └── OfflineGames/
│       ├── Info.plist
│       ├── OfflineGamesApp.swift
│       ├── GameListView.swift
│       ├── GameWebView.swift
│       ├── GameLibraryScanner.swift
│       └── LocalHTTPServer.swift
├── .github/workflows/build.yml
└── .gitignore
```
