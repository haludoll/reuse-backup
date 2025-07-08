import XCTest
@testable import HTTPServerAdapters

final class HTTPServerAdaptersTests: XCTestCase {
    
    func testFactoryCreatesServerBasedOnIOSVersion() throws {
        let server = HTTPServerAdapterFactory.createServer(port: 8080)
        XCTAssertEqual(server.port, 8080)
        
        // Verify that the factory returns the appropriate adapter type
        if #available(iOS 17.0, *) {
            XCTAssertTrue(server is HummingBirdV2Adapter)
        } else {
            XCTAssertTrue(server is HummingBirdV1Adapter)
        }
    }
    
    func testFactoryCreatesSpecificServerType() throws {
        // Test V1 adapter creation
        let v1Server = HTTPServerAdapterFactory.createServer(type: .hummingBirdV1, port: 8081)
        XCTAssertEqual(v1Server.port, 8081)
        XCTAssertTrue(v1Server is HummingBirdV1Adapter)
        
        // Test V2 adapter creation (only on iOS 17+)
        if #available(iOS 17.0, *) {
            let v2Server = HTTPServerAdapterFactory.createServer(type: .hummingBirdV2, port: 8082)
            XCTAssertEqual(v2Server.port, 8082)
            XCTAssertTrue(v2Server is HummingBirdV2Adapter)
        }
    }
}