import Foundation

/// HTTPサーバーアダプターを作成するファクトリー
///
/// HummingBird v1.xベースの統一されたインターフェースを提供します。
/// iOS 15+ 対応で、古いiPhoneでも動作可能です。
public enum HTTPServerAdapterFactory {
    
    /// 指定されたポートでHTTPサーバーアダプターを作成
    /// - Parameter port: サーバーが使用するポート番号
    /// - Returns: HTTPServerAdapterProtocolに準拠するサーバーインスタンス
    public static func createServer(port: UInt16) -> HTTPServerAdapterProtocol {
        return HummingBirdV1Adapter(port: port)
    }
}