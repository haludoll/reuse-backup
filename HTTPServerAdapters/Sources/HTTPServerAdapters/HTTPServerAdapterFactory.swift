import Foundation

/// HTTPサーバーアダプターを作成するファクトリー
///
/// 実行環境に応じて最適なHTTPサーバー実装を選択し、
/// 統一されたインターフェースで提供します。
public enum HTTPServerAdapterFactory {
    
    /// 指定されたポートでHTTPサーバーアダプターを作成
    /// - Parameter port: サーバーが使用するポート番号
    /// - Returns: HTTPServerAdapterProtocolに準拠するサーバーインスタンス
    public static func createServer(port: UInt16) -> HTTPServerAdapterProtocol {
        if #available(iOS 15.0, *) {
            // iOS 15以上: HummingBird v1.x (TLS対応)
            return HummingBirdV1Adapter(port: port)
        } else {
            // フォールバック: FlyingFox (HTTP専用)
            return FlyingFoxAdapter(port: port)
        }
    }
    
    /// 特定の実装を強制的に使用するためのファクトリーメソッド
    public enum ServerType {
        case flyingFox
        case hummingBirdV1
    }
    
    /// 指定された実装でHTTPサーバーアダプターを作成
    /// - Parameters:
    ///   - type: 使用するサーバー実装タイプ
    ///   - port: サーバーが使用するポート番号
    /// - Returns: HTTPServerAdapterProtocolに準拠するサーバーインスタンス
    public static func createServer(type: ServerType, port: UInt16) -> HTTPServerAdapterProtocol {
        switch type {
        case .flyingFox:
            return FlyingFoxAdapter(port: port)
        case .hummingBirdV1:
            return HummingBirdV1Adapter(port: port)
        }
    }
}