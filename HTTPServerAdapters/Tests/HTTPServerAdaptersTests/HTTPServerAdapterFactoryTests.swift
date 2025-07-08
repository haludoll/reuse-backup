import XCTest
import HTTPTypes
@testable import HTTPServerAdapters

final class HTTPServerAdapterFactoryTests: XCTestCase {
    
    func testCreateServerReturnsAppropriateAdapter() {
        let server = HTTPServerAdapterFactory.createServer(port: 8080)
        
        if #available(iOS 15.0, *) {
            XCTAssertTrue(server is HummingBirdV1Adapter, "Should return HummingBirdV1Adapter on iOS 15+")
        } else {
            XCTAssertTrue(server is FlyingFoxAdapter, "Should return FlyingFoxAdapter on iOS 14 and below")
        }
    }
    
    func testCreateServerWithSpecificTypeFlyingFox() {
        let server = HTTPServerAdapterFactory.createServer(type: .flyingFox, port: 8080)
        XCTAssertTrue(server is FlyingFoxAdapter, "Should return FlyingFoxAdapter when explicitly requested")
    }
    
    func testCreateServerWithSpecificTypeHummingBirdV1() {
        let server = HTTPServerAdapterFactory.createServer(type: .hummingBirdV1, port: 8080)
        XCTAssertTrue(server is HummingBirdV1Adapter, "Should return HummingBirdV1Adapter when explicitly requested")
    }
    
    func testServerHasCorrectPort() {
        let testPort: UInt16 = 9090
        let server = HTTPServerAdapterFactory.createServer(port: testPort)
        XCTAssertEqual(server.port, testPort, "Server should have the correct port")
    }
}

// テスト用のモックハンドラー
private struct MockHandler: HTTPHandlerAdapter {
    func handleRequest(_ request: HTTPRequestInfo) async throws -> HTTPResponseInfo {
        return HTTPResponseInfo(
            status: .ok,
            headerFields: HTTPFields([HTTPField(name: .contentType, value: "application/json")]),
            body: Data("{\"status\":\"ok\"}".utf8)
        )
    }
}

final class HTTPServerAdapterProtocolTests: XCTestCase {
    
    func testFlyingFoxAdapterBasicFunctionality() async {
        let adapter = FlyingFoxAdapter(port: 8081)
        let mockHandler = MockHandler()
        let route = HTTPRouteInfo(method: .get, path: "/test")
        
        await adapter.appendRoute(route, to: mockHandler)
        
        // 基本的な機能テスト（実際のサーバー起動はしない）
        XCTAssertEqual(adapter.port, 8081)
    }
    
    func testHummingBirdV1AdapterBasicFunctionality() async {
        let adapter = HummingBirdV1Adapter(port: 8082)
        let mockHandler = MockHandler()
        let route = HTTPRouteInfo(method: .post, path: "/api/test")
        
        await adapter.appendRoute(route, to: mockHandler)
        
        XCTAssertEqual(adapter.port, 8082)
    }
}