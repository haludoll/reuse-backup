# ReuseBackup - 技術仕様

## アーキテクチャ

### 基本構成
- **古いiPhone**: HTTPサーバー（HummingBird）
- **新しいiPhone**: HTTPクライアント（URLSession）
- **通信**: HTTP/1.1 + Bonjour発見
- **方向**: クライアント → サーバー（一方向）

## 技術スタック

### 古いiPhone (サーバー)
- **OS**: iOS 15+
- **言語**: Swift 5.9+
- **HTTPサーバー**: HummingBird
- **サービス発見**: Network Framework (Bonjour)

### 新しいiPhone (クライアント)
- **OS**: iOS 17+
- **言語**: Swift 6
- **HTTP通信**: URLSession
- **UI**: SwiftUI

## プロジェクト構成

```
ReuseBackup/
├── ReuseBackupServer/          # iOS 15対応
├── ReuseBackupClient/          # iOS 17対応
├── SharedModels/               # 共通データモデル
└── docs/
```

## 最小MVP仕様

### 基本通信
- **エンドポイント**: `POST /message`
- **データ**: JSON `{"text": "メッセージ"}`
- **機能**: 新しいスマホから古いスマホへ文字列送信・表示

### Bonjour設定
- **サービスタイプ**: `_messageserver._tcp`
- **サービス名**: デバイス固有識別子
- **ポート**: 8080

## データモデル

### MessageRequest/Response
```swift
struct MessageRequest: Codable {
    let text: String
}

struct MessageResponse: Codable {
    let success: Bool
    let message: String
}
```

## 開発マイルストーン

### Phase 1: MVP（2週間）
- 基本通信確立
- 文字列送受信UI

### 将来Phase
- 写真機能追加
- 動画機能追加