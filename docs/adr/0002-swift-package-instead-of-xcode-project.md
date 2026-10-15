# Xcode プロジェクトではなく Swift Package で作る

Mac アプリは Xcode プロジェクトで作るのが普通だが、このアプリは `Package.swift` だけで構成し、`swift build --build-system swiftbuild` でビルドした実行ファイルを `Scripts/build-app.sh` で `.app` に束ねる。AI が CLI から再現可能にビルド・テストでき、プロジェクトファイルの差分管理が不要で、追加の道具（XcodeGen など）も要らないため。

## Considered Options

- XcodeGen で `.xcodeproj` を生成: brew での道具追加が要る
- ユーザーが Xcode の GUI でプロジェクトを作る: 変更のたびにユーザーの手が要る

## Consequences

- Info.plist、ローカライズした表示名、リソースバンドルの配置、署名はビルドスクリプトが担う
- `Bundle.module` が `.app/Contents/Resources` を探すのは Swift Build バックエンドの生成コードだけなので、`--build-system swiftbuild` を外せない
- Xcode で開くときは `Package.swift` を開く（実行は `.app` 経由）
