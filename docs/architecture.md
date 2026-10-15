# コピペストレージ — C4 モデル

レベル 1〜3 を Mermaid の C4 記法で持つ。レベル 4（コード）は図を描かず、`Sources/` のコードを正とする。

### レベル 1: システムコンテキスト

```mermaid
C4Context
  title コピペストレージ — システムコンテキスト
  Person(user, "利用者", "Mac で文字・画像・ファイルをコピーして貼る人")
  System(app, "コピペストレージ", "クリップボード履歴を取り込み、ショートカットから書式を保ったまま貼り付ける常駐アプリ")
  System_Ext(pb, "ペーストボード", "macOS の共有クリップボード (NSPasteboard)")
  System_Ext(apps, "他のアプリ", "元アプリ・貼り先になる任意のアプリ（パスワード管理ツールを含む）")
  System_Ext(settings, "システム設定", "貼り付けの権限（アクセシビリティ）、読み取りの許可、ログイン項目")
  System_Ext(disk, "ディスク", "~/Library/Application Support")
  Rel(user, apps, "⌘C でコピーする")
  Rel(apps, pb, "内容を書く（秘匿・一時の印を付けることがある）")
  Rel(user, app, "⇧⌘V / クリックで呼び出し、クリップを選ぶ")
  Rel(app, pb, "変化を見て全形式を取り込む／書き戻す")
  Rel(app, apps, "⌘V を送る (CGEvent)")
  Rel(app, disk, "履歴を保存する")
  Rel(app, settings, "権限の案内で開く")
  Rel(settings, app, "権限を与える・ログイン項目に登録する")
```

### レベル 2: コンテナ

```mermaid
C4Container
  title コピペストレージ — コンテナ
  Person(user, "利用者", "")
  System_Boundary(boundary, "コピペストレージ (Copipe Storage.app)") {
    Container(ui, "CopipeStorage", "実行ファイル: Swift, AppKit, SwiftUI", "メニューバー・パネル・設定・権限の案内。OS との配線")
    Container(core, "CopipeCore", "Swift ライブラリ", "取り込み・重複・上限・保存・貼り付けの論理。GUI を持たない")
    Container(ks, "KeyboardShortcuts", "外部ライブラリ (Carbon, MIT)", "グローバルショートカットの登録と記録 UI")
    ContainerDb(store, "履歴ストア", "clips/<id>/ が正本、index.json は並び順のキャッシュ", "manifest、全形式のバイト列、サムネイル")
    ContainerDb(prefs, "設定", "UserDefaults", "件数上限。ショートカットは KeyboardShortcuts が保存")
  }
  System_Ext(pb, "ペーストボード", "NSPasteboard")
  System_Ext(apps, "他のアプリ", "元アプリ・貼り先")
  System_Ext(settings, "システム設定", "権限・ログイン項目")
  Rel(user, ui, "呼び出し・選択")
  Rel(ui, core, "開始／停止、履歴の購読、貼り付けの依頼")
  Rel(ui, ks, "ショートカットの登録・記録")
  Rel(ks, ui, "押下を通知")
  Rel(core, pb, "取り込み・書き戻し")
  Rel(core, apps, "⌘V を送る")
  Rel(core, store, "読み書き")
  Rel(ui, prefs, "読み書き")
  Rel(ui, settings, "案内で開く／ログイン項目の登録")
```

### レベル 3: コンポーネント（CopipeCore）

```mermaid
C4Component
  title CopipeCore — コンポーネント
  Container_Boundary(core, "CopipeCore") {
    Component(capture, "CaptureService", "@MainActor", "0.5 秒ごとに changeCount を見て取り込みを起動。読み取りの拒否を通知")
    Component(reader, "PasteboardReader", "AppKit", "全 item・全形式を読む。大きさ上限で中断、stale 検出")
    Component(markers, "PasteboardMarkers", "", "秘匿・一時・自動生成・自前マーカーの判定")
        Component(tracker, "FrontmostAppTracker", "@MainActor", "自アプリ以外の最後の前面アプリ")
    Component(hasher, "ContentHasher", "CryptoKit", "全形式の SHA-256")
    Component(store, "FileHistoryStore", "actor", "索引・重複・LRU 上限・永続化・復旧")
    Component(preview, "PreviewBuilder / TextExtractor / ThumbnailMaker", "ImageIO", "プレビュー文字列（先頭だけ復号）、文字の取り出し、サムネイル")
    Component(paste, "PasteService", "@MainActor", "コピー／貼り付け／書式なし貼り付けの手順")
    Component(writer, "PasteboardWriter", "AppKit", "全形式の書き戻しと自分の書き込みの記録")
    Component(perm, "PostEventPermission", "CoreGraphics", "貼り付けの権限の確認と要求")
    Component(activator, "TargetActivator", "AppKit", "貼り先の再アクティブ化（自アプリがアクティブな時のみ）")
    Component(poster, "CGEventPoster", "CoreGraphics", "⌘V の送出")
  }
  System_Ext(pb, "ペーストボード", "")
  ContainerDb(disk, "履歴ストア", "ファイル", "")
  System_Ext(apps, "貼り先アプリ", "")
  Rel(capture, reader, "読む")
  Rel(reader, pb, "types / data(forType:)")
  Rel(capture, markers, "判定")
  Rel(capture, tracker, "元アプリ")
  Rel(capture, store, "ingest")
  Rel(store, hasher, "hash")
  Rel(store, preview, "生成")
  Rel(store, disk, "読み書き")
  Rel(paste, store, "loadRepresentations / touch")
  Rel(paste, writer, "書く")
  Rel(writer, pb, "clearContents / writeObjects")
  Rel(writer, capture, "noteOwnWrite")
  Rel(paste, perm, "確認")
  Rel(paste, activator, "必要時")
  Rel(paste, poster, "⌘V")
  Rel(poster, apps, "CGEvent")
```

### レベル 3: コンポーネント（CopipeStorage 実行ファイル）

```mermaid
C4Component
  title CopipeStorage（実行ファイル）— コンポーネント
  Container_Boundary(ui, "CopipeStorage") {
    Component(delegate, "AppDelegate / AppMainMenu / SingleInstance", "NSApplicationDelegate", "二重起動の防止、メインメニュー、配線、ショートカット登録、DEBUG URL")
    Component(status, "StatusItemController", "NSStatusItem", "左クリック→パネル、右クリック→メニュー")
    Component(panelc, "PanelController / HistoryPanel / FloatingPanel", "NSPanel (nonactivating)", "取り込みを待ってから表示、配置、閉じる、貼り先の記憶")
    Component(panelv, "PanelRootView / PanelViewModel / KeyCommand", "SwiftUI", "絞り込み欄、履歴の行、キー操作")
    Component(coordinator, "PasteCoordinator", "", "パネルを閉じて貼り付けを依頼し、結果に応じて案内を出す")
    Component(guide, "GuidePanelController / PastePermissionGuideView", "FloatingPanel + SwiftUI", "権限の案内、コピー済み・貼り付け失敗の通知（key にしない）")
    Component(settingsw, "SettingsWindowController / SettingsView", "NSWindow + SwiftUI", "ショートカット、ログイン時起動、件数上限、このアプリについて")
    Component(appsettings, "AppSettings", "UserDefaults", "件数上限の保存と反映")
    Component(login, "LaunchAtLogin", "SMAppService", "ログイン項目の登録状態")
    Component(actions, "AppMenu", "NSMenu", "設定・全消去・終了のメニュー（右クリックと歯車で共用。target は AppDelegate）")
    Component(l10n, "L10n", "String Catalog", "日本語／英語の文言")
    Component(debug, "DebugURLHandler", "#if DEBUG", "copipestorage:// の処理")
  }
  Container(core, "CopipeCore", "ライブラリ", "")
  Container(ks, "KeyboardShortcuts", "外部ライブラリ", "")
  System_Ext(settings, "システム設定", "")
  Rel(delegate, status, "生成")
  Rel(delegate, ks, "onKeyDown(for: .togglePanel)")
  Rel(ks, panelc, "toggle")
  Rel(status, panelc, "toggle")
  Rel(status, actions, "メニュー")
  Rel(panelc, panelv, "載せる")
  Rel(panelv, core, "snapshot / updates / delete")
  Rel(panelv, coordinator, "activate(clip, mode)")
  Rel(coordinator, core, "paste")
  Rel(coordinator, guide, "権限が無いとき・貼り先に切り替えられないとき表示")
  Rel(guide, settings, "開く")
  Rel(actions, settingsw, "設定…")
  Rel(actions, core, "deleteAll（確認後）")
  Rel(settingsw, appsettings, "件数上限")
  Rel(appsettings, core, "updateLimits")
  Rel(settingsw, ks, "Recorder")
  Rel(settingsw, login, "register / unregister")
  Rel(login, settings, "ログイン項目")
  Rel(settingsw, core, "updateLimits")
  Rel(debug, panelc, "toggle / snapshot")
```

### レベル 4: コード

図は描かない。`Sources/CopipeCore/Model/` の型（`Clip` / `Representation` / `Limits` / `AppIdentity` など）と `Sources/` の配置が正。部品の名前や責務を変えたときは、このファイルのレベル 3 の図を合わせて更新する。
