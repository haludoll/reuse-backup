// HTTPServerAdapters
// 
// このモジュールは、異なるHTTPサーバー実装（FlyingFox、HummingBird等）を
// 統一されたインターフェースで利用するためのアダプターを提供します。

// プロトコルとファクトリー
@_exported import struct HTTPTypes.HTTPRequest
@_exported import struct HTTPTypes.HTTPResponse
@_exported import struct HTTPTypes.HTTPFields
@_exported import struct HTTPTypes.HTTPField

// 公開インターフェース
public protocol HTTPServerAdapter: HTTPServerAdapterProtocol {}

extension FlyingFoxAdapter: HTTPServerAdapter {}
extension HummingBirdV1Adapter: HTTPServerAdapter {}