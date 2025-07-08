import Foundation
import HTTPServerAdaptersCore

/// HTTPサーバーアダプターを作成するファクトリー
///
/// 実行環境に応じて最適なHTTPサーバー実装を選択し、
/// 統一されたインターフェースで提供します。
public enum HTTPServerAdapterFactory {
    
    /// 指定されたポートでHTTPサーバーアダプターを作成
    /// - Parameter port: サーバーが使用するポート番号
    /// - Returns: HTTPServerAdapterProtocolに準拠するサーバーインスタンス
    public static func createServer(port: UInt16) -> HTTPServerAdapterProtocol {
        if #available(iOS 17.0, *) {
            // iOS 17以上: HummingBird v2.x (最新版)
            return HummingBirdV2Adapter(port: port)
        } else if #available(iOS 15.0, *) {
            // iOS 15-16: HummingBird v1.x
            return HummingBirdV1Adapter(port: port)
        } else {
            // iOS 15未満はサポート外
            fatalError("HTTPServerAdapters requires iOS 15.0 or later")
        }
    }
    
    /// 特定の実装を強制的に使用するためのファクトリーメソッド
    public enum ServerType {
        case hummingBirdV1
        case hummingBirdV2
    }
    
    /// 指定された実装でHTTPサーバーアダプターを作成
    /// - Parameters:
    ///   - type: 使用するサーバー実装タイプ
    ///   - port: サーバーが使用するポート番号
    /// - Returns: HTTPServerAdapterProtocolに準拠するサーバーインスタンス
    public static func createServer(type: ServerType, port: UInt16) -> HTTPServerAdapterProtocol {
        switch type {
        case .hummingBirdV1:
            return HummingBirdV1Adapter(port: port)
        case .hummingBirdV2:
            if #available(iOS 17.0, *) {
                return HummingBirdV2Adapter(port: port)
            } else {
                fatalError("HummingBird v2 requires iOS 17.0 or later")
            }
        }
    }
}