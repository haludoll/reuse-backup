import XCTest
import HTTPTypes
@testable import HTTPServerAdapters

final class HTTPServerAdapterFactoryTests: XCTestCase {
    
    func testCreateServerReturnsAppropriateAdapter() {
        let server = HTTPServerAdapterFactory.createServer(port: 8080)
        
        if #available(iOS 17.0, *) {
            XCTAssertTrue(server is HummingBirdV2Adapter, "Should return HummingBirdV2Adapter on iOS 17+")
        } else if #available(iOS 15.0, *) {
            XCTAssertTrue(server is HummingBirdV1Adapter, "Should return HummingBirdV1Adapter on iOS 15-16")
        } else {
            XCTFail("iOS 15.0 or later is required")
        }
    }
    
    func testCreateServerWithSpecificTypeHummingBirdV1() {
        let server = HTTPServerAdapterFactory.createServer(type: .hummingBirdV1, port: 8080)
        XCTAssertTrue(server is HummingBirdV1Adapter, "Should return HummingBirdV1Adapter when explicitly requested")
    }
    
    func testCreateServerWithSpecificTypeHummingBirdV2() {
        if #available(iOS 17.0, *) {
            let server = HTTPServerAdapterFactory.createServer(type: .hummingBirdV2, port: 8080)
            XCTAssertTrue(server is HummingBirdV2Adapter, "Should return HummingBirdV2Adapter when explicitly requested")
        } else {
            // iOS 17未満では HummingBirdV2 は使用できない
            XCTSkip("HummingBird v2 requires iOS 17.0 or later")
        }
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
    
    func testHummingBirdV1AdapterBasicFunctionality() async {
        let adapter = HummingBirdV1Adapter(port: 8082)
        let mockHandler = MockHandler()
        let route = HTTPRouteInfo(method: .post, path: "/api/test")
        
        await adapter.appendRoute(route, to: mockHandler)
        
        XCTAssertEqual(adapter.port, 8082)
    }
    
    func testHummingBirdV2AdapterBasicFunctionality() async {
        if #available(iOS 17.0, *) {
            let adapter = HummingBirdV2Adapter(port: 8083)
            let mockHandler = MockHandler()
            let route = HTTPRouteInfo(method: .get, path: "/test")
            
            await adapter.appendRoute(route, to: mockHandler)
            
            XCTAssertEqual(adapter.port, 8083)
        } else {
            XCTSkip("HummingBird v2 requires iOS 17.0 or later")
        }
    }
}