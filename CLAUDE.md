# コピペストレージ

## ビルドと実行

- `make build` / `make test` / `make app` / `make app-debug` / `make run` / `make stop` / `make sign-check`
- `swift build` と `swift test` は必ず `--build-system swiftbuild` 付きで呼ぶ（Makefile 経由）。native バックエンドだと `.app` 内で `Bundle.module` が解決しない
- `@main` の型を `main.swift` に置かない（SE-0281 でエラーになる）
- 署名 identity は自己署名の `Copipe Storage Dev`。無いときはアドホック署名になり、ビルドごとに貼り付けの権限（システム設定の「アクセシビリティ」）が外れる。鍵の利用許可を求めるキーチェーンのダイアログが出ると codesign が止まるので、「常に許可」にしておく
- 貼り付けの権限は、付与後にアプリを再起動しないと反映されないことがある
- 保存は `clips/<id>/manifest.json` が正本で、`index.json` は並び順のキャッシュ。`index.json` に無いディレクトリを削除する処理を入れてはいけない（docs/adr/0004）
- メニューバーは出さないが `NSApp.mainMenu` に編集メニューを置く。無いと文字欄で ⌘V/⌘A/⌘Z が配送されない

## 検証のしかた

- デバッグ構成の `.app` は `copipestorage://` の URL を受ける（一覧は README）。パネルやキー操作はこれで起こす
- ログは `/usr/bin/log` を使う（zsh の組み込み `log` が同名で先に解決される）。`info` レベルは `log show` に残らないので `log stream --level info` で受ける
- 画面は `screencapture -x` で撮れる（Claude アプリに画面収録の許可あり）。ウィンドウ単位は `-l <windowID>`。画面外（隠れたメニューバーなど）は撮れない
- `osascript` は自動化の許可ダイアログを出すので使わない
- Bash を並行実行すると作業ディレクトリが共有されて相対パスが壊れる。ファイル操作は絶対パスで行う

## コードの制約

- NSPasteboard の読み書きは MainActor 上でのみ行う。`NSPasteboardItem` を actor の外へ出さない
- SwiftUI の文言は `bundle: .module` を付ける（`Text("key", bundle: .module)` または `L10n.string`）。`Bundle.main` には無い
- ユーザー向け文言は CopipeStorage 側に置く。CopipeCore は文言を持たない
- ⌘ 付きのキーは SwiftUI の `onKeyPress` に届かない。`HistoryPanel.performKeyEquivalent` → `KeyCommand.handleCommandKey` で受ける
- 案内の小窓（GuidePanelController）は key にしない。貼り先のキー入力を奪わないため、ボタンにキー割り当ても付けない
- 日本語入力の変換中（`hasMarkedText`）は Return と ↑↓ を IME に渡す
- 用語は CONTEXT.md に従う。設計の経緯は docs/adr/、構成は docs/architecture.md
