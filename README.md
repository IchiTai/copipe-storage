# コピペストレージ (Copipe Storage)

macOS のクリップボード履歴を取り込み、ショートカットから書式を保ったまま貼り付ける常駐アプリ。

- ⌥C（設定で変更可）で画面中央にパネルが開く。メニューバーのアイコンの左クリックでも同じ。英語配列では ⌥C で「ç」を打てなくなる
- 文字（書式付きを含む）・画像・ファイル参照を、元アプリが載せた全形式のまま保存する。貼るときも全形式を書き戻すので書式が失われない
- パネルの操作: ↑↓ で選択、Enter で貼り付け、⇧Enter で書式なし貼り付け、⌘Enter・⌘クリック・行のコピーボタンでクリップボードに載せるだけ、⌘1〜9 で上から 9 件を即貼り、⌘⌫ で削除、Esc で閉じる。文字を打つとその場で絞り込み
- 同じ内容（全形式が一致）は 1 件にまとめて先頭へ。件数上限（既定 1000、設定で 100〜3000）を超えると、最後に使ったのが古いものから消える
- パスワード管理ツールなどが「秘匿」「一時」「自動生成」の印（nspasteboard.org の規約）を付けた内容は取り込まない
- 履歴は `~/Library/Application Support/jp.ichitai.copipestorage/` に保存され、再起動後も残る。クリップごとの `manifest.json` が正本で、`index.json` は並び順のキャッシュ（壊れても作り直される）
- 同時に 2 つは起動しない（2 つ目は「すでに起動しています」と表示して終了する）

## 対応環境とビルド

対応 OS: macOS 15 以上（動作確認は macOS 26.7）。Xcode 27 / Swift 6.4 で開発。

```
make test       # CopipeCore のテスト（Swift Testing）
make app        # build/Copipe Storage.app を組み立てて署名（リリース構成）
make app-debug  # 同上（デバッグ構成。検証用の URL スキームが有効）
make run        # 組み立てて起動
make stop       # 終了
```

- Xcode プロジェクトは無く、`Package.swift` だけで構成する。`swift build` は必ず `--build-system swiftbuild` 付きで呼ぶ（Makefile 経由）。native バックエンドだと `.app` 内で `Bundle.module` が解決しない（docs/adr/0002）
- 署名は自己署名の identity `Copipe Storage Dev`（キーチェーンアクセスで「自己署名ルート」「コード署名」として作成し、「コード署名」を「常に信頼」にする）。無いときはアドホック署名になり、ビルドのたびに貼り付けの権限が外れる
- 配布する場合は Developer ID での署名と公証が要る（未対応）

## 権限

- **貼り付け**: 選んだクリップを貼り先のアプリへ送る（⌘V を送出する）ために、システム設定 >「プライバシーとセキュリティ」>「アクセシビリティ」で許可が要る。許可が無いときは案内が出て、その回はクリップボードに載せるだけになる（⌘V で貼れる）。**許可したあとはアプリを一度終了して起動し直す**（起動中のプロセスには反映されないことがある）
- **読み取りの許可**: macOS 15.4 以降にはアプリのクリップボード読み取りに許可を求める仕組みがあるが、macOS 26.7 時点では既定で無効。拒否されている状態を検知したときだけ案内を出す
- **ログイン時に起動**: アプリを「アプリケーション」フォルダに置いてから設定でオンにする。置き場所を移すと登録が外れる

## 既知の制限

- 1 クリップの大きさが 50 MB を超える内容は通知なしで取り込まない
- ファイル参照のクリップは、貼る時点でファイルが無くてもそのまま貼る
- ⌘V の送出はキーコード 9（US/JIS 配列の V）固定。Dvorak などでは V にならない
- 元アプリが遅延提供するデータ（巨大なデータや Universal Clipboard）は、取り込み時に相手アプリの応答を待つため一瞬止まることがある
- 文字の形式を持つ画像（表計算のセル範囲など）は画像として扱い、行にはサムネイルと文字の両方を出す
- 書式なし貼り付けを、文字の形式を持たないクリップ（画像・ファイル参照）に対して行うと、元の形式のまま貼る。RTF や HTML しか無いクリップは、そこから文字を取り出して貼る

## 構成と資料

- `Sources/CopipeCore`: 取り込み・保存・貼り付けの論理（GUI 無し。テスト対象）
- `Sources/CopipeStorage`: メニューバー・パネル・設定・権限の案内（AppKit + SwiftUI）
- `CONTEXT.md`: 用語集 / `docs/architecture.md`: C4 モデル / `docs/adr/`: 設計の決定 / `CLAUDE.md`: 開発時の制約

## 検証用の URL（デバッグ構成のみ）

`make app-debug` で組み立てたアプリは `copipestorage://` スキームを受け付ける。`open "copipestorage://panel/show"` でパネルを開く、`debug/key?code=36&chars=%0D&mods=cmd` で合成キーを送る、`debug/filter?text=`、`debug/select?delta=`、`debug/settings`、`debug/guide?reason=`、`debug/status`（権限や選択位置などの状態をログに出す。`/usr/bin/log stream --level info --predicate 'subsystem == "jp.ichitai.copipestorage"'` で読む）、`debug/snapshot?path=`。リリース構成には入らない。
