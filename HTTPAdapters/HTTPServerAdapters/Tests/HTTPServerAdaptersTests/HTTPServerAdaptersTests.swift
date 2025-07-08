import XCTest
import HTTPTypes
@testable import HTTPServerAdapters

final class HTTPServerAdaptersTests: XCTestCase {
    
    func testFactoryCreatesHummingBirdV1Server() throws {
        let server = HTTPServerAdapterFactory.createServer(port: 8080)
        XCTAssertEqual(server.port, 8080)
        XCTAssertTrue(server is HummingBirdV1Adapter)
    }
    
    func testHTTPRouteInfoInitialization() {
        let route = HTTPRouteInfo(method: .get, path: "/test")
        XCTAssertEqual(route.method, .get)
        XCTAssertEqual(route.path, "/test")
    }
    
    func testHTTPRequestInfoInitialization() {
        var headerFields = HTTPFields()
        headerFields[.contentType] = "application/json"
        
        let request = HTTPRequestInfo(
            method: .post,
            path: "/api/upload",
            headerFields: headerFields,
            body: Data("test".utf8)
        )
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/api/upload")
        XCTAssertEqual(request.body, Data("test".utf8))
        XCTAssertEqual(request.headerFields[.contentType], "application/json")
    }
    
    func testHTTPResponseInfoInitialization() {
        var headerFields = HTTPFields()
        headerFields[.contentType] = "application/json"
        
        let response = HTTPResponseInfo(
            status: .ok,
            headerFields: headerFields,
            body: Data("response".utf8)
        )
        
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.body, Data("response".utf8))
        XCTAssertEqual(response.headerFields[.contentType], "application/json")
    }
}