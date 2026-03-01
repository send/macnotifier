# CLAUDE.md

macnotifier の実装ガイド。

## 参考実装

[macos-notify-mcp](https://github.com/yuki-yano/macos-notify-mcp) の `MacOSNotifyMCP/main.swift` を参考にする。

### 参考実装から採用するパターン

1. **NSApplication ライフサイクル**
   - `NSApplication.shared.setActivationPolicy(.accessory)` で Dock 非表示
   - `NSApplication.shared.run()` でイベントループ開始
   - クリック処理後に `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)` で遅延終了

2. **UNUserNotificationCenter**
   - `requestAuthorization(options: [.alert, .sound])` で権限要求
   - `trigger: nil` で即時配信
   - `UNMutableNotificationContent.userInfo` にクリック時のメタデータを格納

3. **デリゲート**
   - `UNUserNotificationCenterDelegate.didReceive` でクリックハンドリング
   - `response.notification.request.content.userInfo` からメタデータ取得

4. **ビルド**
   - `swiftc -o` で単一ファイルコンパイル
   - `codesign --force --deep --sign -` で ad-hoc 署名

### 参考実装から変更する点

- MCP サーバー部分は不要。純粋な CLI ツールとして実装する
- tmux 連携は不要。汎用的な `-activate` と `-execute` に置き換える
- コマンドライン引数パーサーは手動実装（外部依存を入れない）

## 技術的制約

### .app バンドルが必須

`UNUserNotificationCenter` は `.app` バンドル内のバイナリからしか動作しない。Info.plist に `CFBundleIdentifier` が必要。

### Info.plist 必須キー

```xml
<key>CFBundleIdentifier</key>
<string>sh.send.macnotifier</string>
<key>LSUIElement</key>
<true/>
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
```

- `LSUIElement: true` — Dock に表示しない
- `NSUserNotificationAlertStyle: alert` — バナーではなくアラートスタイル（ユーザーが明示的に閉じるまで表示）

### 起動方法

`open -n macnotifier.app --args -m "message"` で起動する。`-n` フラグで複数インスタンスを許可。

CLI ラッパースクリプトがこの `open -n` 呼び出しをラップする。

## 実装順序

### Phase 1: 基本通知

1. `Sources/main.swift` を作成
2. `NSApplication` + `UNUserNotificationCenter` で基本的な通知送信
3. `-t` (title) と `-m` (message) の引数パース
4. `scripts/build.sh` で `.app` バンドルビルド
5. 動作確認: `open -n macnotifier.app --args -m "test"`

### Phase 2: クリックアクション

1. `UNUserNotificationCenterDelegate.didReceive` を実装
2. `-e` (execute): `Process()` + `/bin/sh -c` でコマンド実行
3. `-a` (activate): `NSWorkspace.shared.open(URL)` または `osascript` でアプリアクティブ化
4. 両方指定時: execute → activate の順で実行
5. 処理後に `NSApplication.shared.terminate(nil)` で自己終了

### Phase 3: オプション機能

1. `--sound` — `UNNotificationSound(named:)` でカスタム通知音
2. `--icon` — `UNNotificationAttachment` で PNG アイコン添付
3. `-h` (help) — ヘルプ表示

### Phase 4: CLI ラッパーとビルドスクリプト

1. `macnotifier` CLI ラッパースクリプト作成（`open -n` をラップ）
2. `scripts/build.sh` を完成させる（Info.plist 生成、コンパイル、署名、ラッパー生成）

## コマンドライン引数パース

外部依存なしで手動パース。参考実装と同じパターン:

```swift
var i = 1
let args = CommandLine.arguments
while i < args.count {
    switch args[i] {
    case "-t", "--title":
        i += 1; title = args[i]
    case "-m", "--message":
        i += 1; message = args[i]
    // ...
    }
    i += 1
}
```

## クリックアクション実装の詳細

### execute (-e)

```swift
let task = Process()
task.executableURL = URL(fileURLWithPath: "/bin/sh")
task.arguments = ["-c", command]
try task.run()
// waitUntilExit() は不要（バックグラウンドで実行させる）
```

### activate (-a)

バンドル ID からアプリをアクティブ化:

```swift
if let url = NSWorkspace.shared.urlForApplication(
    withBundleIdentifier: bundleId
) {
    NSWorkspace.shared.open(url)
}
```

## ビルドスクリプト要件

`scripts/build.sh` が行うこと:

1. `.app` バンドルのディレクトリ構造を作成
2. `Info.plist` を生成
3. `swiftc` でコンパイル
4. アイコンがあれば `Resources/` にコピー
5. `codesign --force --deep --sign -` で ad-hoc 署名
6. CLI ラッパースクリプトを生成

## 検証手順

1. `./scripts/build.sh` で `.app` バンドルがビルドできること
2. `./macnotifier -m "test"` で通知が表示されること
3. `./macnotifier -m "test" -e "echo clicked > /tmp/test"` でクリック時にコマンド実行
4. `./macnotifier -m "test" -a com.github.wez.wezterm` でクリック時に WezTerm がアクティブ化
5. 通知クリック後にプロセスが終了すること
