# メッセージング機能仕様書

## 概要

ReuseBackupアプリケーションにおけるクライアント・サーバー間のメッセージ送受信機能の外部仕様書です。

## 機能概要

### 基本機能
- **メッセージ送信**: クライアントからサーバーへのテキストメッセージ送信
- **メッセージ受信**: サーバーでのメッセージ受信・表示
- **送信確認**: メッセージ送信結果の確認
- **メッセージ管理**: 受信したメッセージの管理

## クライアント側機能

### メッセージ入力
- **入力形式**: 多行テキスト入力対応
- **文字数制限**: 1〜1000文字
- **リアルタイム文字数表示**: 入力中の文字数とリミット表示
- **制限超過警告**: 1000文字を超えた場合の警告表示

### 送信機能
- **送信条件**: 
  - サーバーに接続済み
  - 1文字以上のメッセージ
  - 1000文字以内
  - 送信中でない状態
- **送信処理**: 
  - 送信中のプログレス表示
  - 送信ボタンの無効化
  - タイムアウト処理（30秒）

### 送信結果表示
- **成功時**: 
  - 送信成功アラート表示
  - 入力フィールドの自動クリア
  - サーバーレスポンス詳細表示
- **失敗時**: 
  - エラーアラート表示
  - 詳細エラーメッセージ表示
  - 再試行ボタン提供

### レスポンス詳細表示
- **処理ステータス**: `success` または `error`
- **受信確認**: メッセージ受信成功/失敗
- **サーバー時刻**: サーバーでの受信時刻（UTC）
- **エラー詳細**: エラー発生時の詳細情報

## サーバー側機能

### メッセージ受信
- **受信処理**: HTTP POST リクエストの受信
- **JSON解析**: リクエストボディのJSON解析
- **バリデーション**: メッセージ内容の検証
- **タイムスタンプ記録**: 受信時刻の記録

### メッセージ表示
- **リアルタイム表示**: 受信メッセージの即座の表示
- **メッセージ一覧**: 受信したメッセージの時系列表示
- **空状態表示**: メッセージがない場合の表示

### メッセージ管理
- **メッセージ保存**: 受信したメッセージの一時保存
- **メッセージクリア**: 受信メッセージ一覧のクリア機能
- **メッセージ制限**: 保存するメッセージ数の上限管理

## データ形式

### 送信メッセージ
```json
{
  "message": "送信するメッセージ内容",
  "timestamp": "2025-07-08T12:00:00Z"
}
```

### 受信応答（成功）
```json
{
  "status": "success",
  "received": true,
  "serverTimestamp": "2025-07-08T12:00:01Z"
}
```

### 受信応答（エラー）
```json
{
  "status": "error",
  "error": "エラーメッセージ",
  "received": false
}
```

## 制限事項

### メッセージ制限
- **最大文字数**: 1000文字
- **最小文字数**: 1文字
- **対応文字**: UTF-8（絵文字含む）
- **改行**: 対応

### 送信制限
- **同時送信**: 1つのメッセージのみ
- **送信間隔**: 制限なし
- **タイムアウト**: 30秒

### 保存制限
- **サーバー側**: アプリ終了まで保存
- **クライアント側**: レスポンス情報のみ保存
- **永続化**: なし（メモリ上のみ）

## エラーハンドリング

### 入力エラー
- **空メッセージ**: 1文字以上の入力要求
- **文字数超過**: 1000文字以内への修正要求
- **無効文字**: 特殊制御文字の除去

### 送信エラー
- **ネットワークエラー**: 接続失敗時の再試行提案
- **サーバーエラー**: サーバー側エラーの表示
- **タイムアウト**: 送信タイムアウト時の再試行

### 受信エラー
- **JSON解析エラー**: 無効なJSON形式の処理
- **必須フィールド不足**: 必須パラメータの不足処理
- **サーバー内部エラー**: サーバー側処理エラー

## ユーザーエクスペリエンス

### 送信フロー
1. **メッセージ入力**: テキストエディタでメッセージ入力
2. **文字数確認**: リアルタイムでの文字数チェック
3. **送信実行**: 送信ボタンタップ
4. **送信中表示**: プログレスインジケーター表示
5. **結果確認**: 送信結果の確認
6. **次のメッセージ**: 成功時の入力フィールドクリア

### 受信フロー
1. **メッセージ受信**: HTTP POST リクエスト受信
2. **即座表示**: 受信メッセージの即座の画面表示
3. **一覧更新**: メッセージ一覧への追加
4. **レスポンス**: クライアントへの応答送信

## 関連仕様

- **[API仕様](../api/README.md)** - メッセージAPI詳細
- **[クライアントアプリ仕様](../client/README.md)** - クライアント側UI詳細
- **[サーバーアプリ仕様](../server/README.md)** - サーバー側処理詳細
- **[ネットワーク仕様](../network/README.md)** - 通信プロトコル詳細