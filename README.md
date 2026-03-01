# macnotifier

Modern macOS notification CLI using `UNUserNotificationCenter`.

`terminal-notifier` は deprecated な `NSUserNotification` API に依存しており、macOS 26 ではクリックアクション（`-activate`, `-execute`）が動作しない。本ツールはモダンな `UNUserNotificationCenter` API を使い、クリック時のアプリアクティブ化やコマンド実行を確実に動作させる。

## インストール

```sh
brew install send/tap/macnotifier
```

## 使い方

```sh
macnotifier -m "Hello, World!"
macnotifier -t "Build" -m "Success" --sound "Glass"
macnotifier -m "Done" -a com.github.wez.wezterm
macnotifier -m "Done" -e "echo clicked > /tmp/test"
macnotifier -m "Done" -e "echo clicked" -a com.github.wez.wezterm
macnotifier -m "Done" --icon /path/to/icon.png

# stdin からメッセージを読む (-m 省略時)
echo "Hello from pipe" | macnotifier
echo "Build failed" | macnotifier -t "CI"
```

## CLI インターフェース

```
macnotifier [options]
command | macnotifier [options]

Options:
  -t, --title <text>        通知タイトル (default: "macnotifier")
  -m, --message <text>      通知メッセージ (-m 省略時は stdin から読む)
  -a, --activate <bundleId> クリック時にアプリをアクティブ化
  -e, --execute <command>   クリック時にコマンドを実行
  --sound <name>            ~/Library/Sounds または /System/Library/Sounds のサウンド名 (e.g. "Glass")
  --icon <path>             通知に添付する画像ファイルのパス
  -h, --help                ヘルプ表示
```

- `-m` を省略して stdin をパイプすると、stdin の内容がメッセージになる
- `-a` と `-e` は併用可能（execute 実行後に activate）
- どちらも未指定の場合はクリックで通知を閉じるだけ

## アーキテクチャ

macOS の通知 API (`UNUserNotificationCenter`) を使うには `.app` バンドルが必要。本ツールは以下の構成で動作する:

```
macnotifier (CLI wrapper script)
  └── open -n macnotifier.app --args ...
        └── macnotifier.app (accessory app)
              ├── 通知を送信
              ├── クリックをデリゲートで受信
              ├── -execute: /bin/sh -c でコマンド実行
              ├── -activate: NSWorkspace でアプリ起動
              └── 自己終了
```

### プロジェクト構造

```
macnotifier/
├── Sources/
│   └── main.swift              # アプリ本体
├── Resources/
│   └── AppIcon.icns            # アプリアイコン
├── bin/
│   └── macnotifier             # CLI ラッパースクリプト
├── scripts/
│   ├── build.sh                # .app バンドルビルド + ad-hoc codesign
│   └── test.sh                 # テストスクリプト
├── README.md
├── CLAUDE.md
├── LICENSE
└── .gitignore
```

### .app バンドル構造（ビルド成果物）

```
macnotifier.app/
  Contents/
    Info.plist
    MacOS/
      macnotifier               # コンパイル済みバイナリ
    Resources/
      macnotifier.icns
```

## ビルド

```sh
./scripts/build.sh
```

`macnotifier.app/` と `macnotifier` (CLI ラッパースクリプト) が生成される。

## 配布

Homebrew tap ([send/homebrew-tap](https://github.com/send/homebrew-tap)) で配布する。

```sh
brew install send/tap/macnotifier
```

## ライセンス

MIT
