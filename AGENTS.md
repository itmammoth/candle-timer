# Repository Guidelines

## 作業上の注意

- ユーザーへの回答は常に日本語で行ってください。
- 明示的な依頼がない限り、コミットやプッシュはしないでください。
- `config.json` は利用者固有のローカル設定であり、Git管理対象外です。設定例の正本は `config.json.sample` とし、ローカル設定の上書きは依頼された場合だけ行ってください。

## プロジェクト構成

このリポジトリは、macOS向けの小規模なSwift CLIユーティリティです。外部依存パッケージはありません。

- `Package.swift`: Swift Packageの構成とmacOS 13以上・Swift 6の指定
- `Sources/CandleTimer/Configuration.swift`: JSON設定のデコードと検証
- `Sources/CandleTimer/CandleSchedule.swift`: タイムゾーンを考慮した通知時刻の純粋な計算
- `Sources/CandleTimer/CandleTimerRunner.swift`: 1秒単位の重複防止、フォールバック状態、`say`への発話依頼
- `Sources/CandleTimer/CandleTimerCommand.swift`: 設定ファイルの探索とCLIの起動
- `Tests/CandleTimerTests/`: 設定、通知境界、Runner、音声引数のテスト
- `config.json.sample`: 現行設定スキーマと実用設定の見本
- `README.md`: 利用者向けの導入手順と設定仕様

実行ファイルは、実行ファイルと同じディレクトリの `config.json` を優先し、見つからなければカレントディレクトリの `config.json` を読み込みます。

## 現行の設定と動作

ルート設定は `timeZone`、任意の `fallback`、1件以上の `periods` で構成します。以前のトップレベル `candle` と `rules` 形式には対応しません。

- `timeZone` は `Asia/Tokyo` などの有効なIANA識別子にします。
- `periods` は開始時刻順に並べ、重複させません。隙間は許可し、`fallback` があればその対象になります。
- `start` と `end` は `HH:mm` 形式です。同日内で `start < end` とし、日またぎは扱いません。
- `candle.durationMinutes` は正の整数とし、periodの長さを割り切れる値にします。各periodの開始時刻が分足の起点です。
- `rules[].when` は `secondsBeforeClose`、`candleClosed: true`、`periodStarted: true` のどれか1つだけを指定します。
- `secondsBeforeClose` は1以上、対象分足の秒数以下にします。`candleClosed` は確定時刻ちょうど、`periodStarted` はperiod開始時刻ちょうどです。
- 同じ秒に複数条件が成立した場合は、終了側の `candleClosed`、開始側の `periodStarted`、`secondsBeforeClose` の順に発話します。同種のルールはJSON上の順序を維持します。
- 空の `speak.message` は発話しません。
- `fallback.intervalMinutes` は正の整数です。どのperiodにも該当しない状態で起動した場合は即時に1回発話し、その後は指定間隔で繰り返します。period終了時に通常通知がある場合はそれを優先し、1間隔後からfallbackを発話します。
- 設定は曜日を問わず毎日適用します。停止中やスリープ中に過ぎた通知は遡って発話しません。

設定スキーマや標準動作を変更するときは、実装、`config.json.sample`、README、設定サンプルの回帰テストを同時に更新してください。

## ビルド・テスト・実行コマンド

- `cp config.json.sample config.json`: 初回のみローカル設定を作成
- `swift run candle-timer`: ビルドして起動。停止は `Ctrl+C`
- `swift build`: デバッグビルド
- `swift build -c release`: リリースビルド
- `swift test`: 全自動テスト
- `jq empty config.json.sample`: サンプルJSONの構文確認

CLIを実行すると実際に音声が再生され、`Ctrl+C`まで終了しません。自動検証では原則として `swift test` とテスト用の `SpeechSynthesizing` 実装を使用してください。

## コーディング規約

Swift 6を対象とし、既存の2スペースインデントを維持します。型名にはUpperCamelCase、プロパティとメソッドにはlowerCamelCase、JSONキーにはlowerCamelCaseを使用してください。

- 設定解析と検証、時刻計算、状態管理、音声出力の責務を分離してください。
- 時刻計算は設定されたタイムゾーンを使用し、Unix秒や固定日時を注入して単体テストできる形にしてください。
- 発話は `SpeechSynthesizing` 経由とし、テストから `/usr/bin/say` を直接起動しないでください。
- 同一秒の重複発話防止と、同秒に成立した複数メッセージの順序を維持してください。
- 設定エラーには、利用者が修正箇所を特定できるメッセージを用意してください。

## テスト方針

すべての変更で最低限 `swift test` を通してください。リリース方法、対応OS、Swiftバージョン、コンパイラ設定を変更した場合は `swift build -c release` も実行します。

挙動や設定を変更した場合は、関連する次の観点をテストします。

- period開始・通常の足確定・period終了・隣接period切り替えの境界
- periodごとの分足とルールが他のperiodへ混入しないこと
- 同じUnix秒を複数回評価しても一度しか発話しないこと
- fallbackの起動直後、繰り返し間隔、periodへの出入り
- タイムゾーン、時刻形式、periodの順序・重複・割り切れない分足、不正な条件や秒数
- 空メッセージ、設定ファイル欠落、旧形式や不正JSONのエラー
- `config.json.sample` が現行パーサーで読み込めること

テストは `Tests/CandleTimerTests/` 以下に置き、検証する挙動が分かる名前を付けてください。実際の読み上げや `Ctrl+C` 終了の手動確認は、音声出力またはRunLoopの挙動を変更した場合に行います。

## コミットとプルリクエスト

コミットは1件の論理的変更に絞り、`Swift CLIへ移行し設定をJSON化` や `時間帯別の分足とフォールバック通知に対応` のような短い日本語の件名にしてください。

プルリクエストには、利用者への影響、設定スキーマの変更、実行した検証コマンド、手動確認結果を記載します。関連Issueがあればリンクし、スクリーンショットは視覚的な変更がある場合だけ添付してください。
