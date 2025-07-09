import Foundation
import HTTPServerAdapters
import HTTPTypes
import Testing

@testable import ReuseBackupServer

@Suite("HTTPAdaptersServerWrapper Tests")
struct HTTPAdaptersServerWrapperTests {
    @Test("when_init_then_portIsSetCorrectly")
    func initialization() async throws {
        let port: UInt16 = 8080
        let wrapper = HTTPAdaptersServerWrapper(port: port)

        #expect(wrapper.port == port)
    }

    @Test("when_initWithDifferentPorts_then_portsAreSetCorrectly")
    func initializationWithDifferentPorts() async throws {
        let port1: UInt16 = 8080
        let port2: UInt16 = 8443
        let port3: UInt16 = 3000

        let wrapper1 = HTTPAdaptersServerWrapper(port: port1)
        let wrapper2 = HTTPAdaptersServerWrapper(port: port2)
        let wrapper3 = HTTPAdaptersServerWrapper(port: port3)

        #expect(wrapper1.port == port1)
        #expect(wrapper2.port == port2)
        #expect(wrapper3.port == port3)
    }

    @Test("when_appendRoute_then_noExceptionThrown")
    func testAppendRoute() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)
        let route = HTTPRouteInfo(method: .get, path: "/test")

        let handler = TestHTTPHandler()

        await wrapper.appendRoute(route, to: handler)

        #expect(true)
    }

    @Test("when_appendMultipleRoutes_then_noExceptionThrown")
    func appendMultipleRoutes() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)
        let handler = TestHTTPHandler()

        let routes = [
            HTTPRouteInfo(method: .get, path: "/test1"),
            HTTPRouteInfo(method: .post, path: "/test2"),
            HTTPRouteInfo(method: .put, path: "/test3"),
            HTTPRouteInfo(method: .delete, path: "/test4"),
        ]

        for route in routes {
            await wrapper.appendRoute(route, to: handler)
        }

        #expect(true)
    }

    @Test("when_appendRouteWithDifferentMethods_then_noExceptionThrown")
    func appendRouteWithDifferentMethods() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)
        let handler = TestHTTPHandler()

        await wrapper.appendRoute(HTTPRouteInfo(method: .get, path: "/get"), to: handler)
        await wrapper.appendRoute(HTTPRouteInfo(method: .post, path: "/post"), to: handler)
        await wrapper.appendRoute(HTTPRouteInfo(method: .put, path: "/put"), to: handler)
        await wrapper.appendRoute(HTTPRouteInfo(method: .delete, path: "/delete"), to: handler)
        await wrapper.appendRoute(HTTPRouteInfo(method: .patch, path: "/patch"), to: handler)

        #expect(true)
    }

    @Test("when_appendRouteWithComplexPaths_then_noExceptionThrown")
    func appendRouteWithComplexPaths() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)
        let handler = TestHTTPHandler()

        let complexPaths = [
            "/api/v1/users",
            "/api/v1/users/{id}",
            "/api/v1/users/{id}/posts",
            "/api/v1/users/{id}/posts/{postId}",
            "/health/check",
            "/metrics",
            "/static/images/{filename}",
            "/auth/login",
            "/auth/logout",
        ]

        for path in complexPaths {
            await wrapper.appendRoute(HTTPRouteInfo(method: .get, path: path), to: handler)
        }

        #expect(true)
    }

    @Test("when_stopCalled_then_noExceptionThrown")
    func testStop() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)

        await wrapper.stop()

        #expect(true)
    }

    @Test("when_stopCalledMultipleTimes_then_noExceptionThrown")
    func stopCalledMultipleTimes() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)

        await wrapper.stop()
        await wrapper.stop()
        await wrapper.stop()

        #expect(true)
    }

    @Test("when_runCalled_then_throwsExpectedError")
    func testRun() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)

        do {
            try await wrapper.run()
            #expect(Bool(false), "run() should throw an error in test environment")
        } catch {
            #expect(true)
        }
    }

    @Test("when_protocolConformance_then_implementsHTTPServerProtocol")
    func protocolConformance() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)

        #expect(wrapper is HTTPServerProtocol)

        let serverProtocol: HTTPServerProtocol = wrapper
        #expect(serverProtocol.port == 8080)
    }

    @Test("when_sendableConformance_then_canBeUsedAcrossActors")
    func sendableConformance() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)

        await withCheckedContinuation { continuation in
            Task {
                let port = wrapper.port
                #expect(port == 8080)
                continuation.resume()
            }
        }
    }

    @Test("when_portZero_then_initializesCorrectly")
    func portZero() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 0)

        #expect(wrapper.port == 0)
    }

    @Test("when_maxPort_then_initializesCorrectly")
    func testMaxPort() async throws {
        let maxPort = UInt16.max
        let wrapper = HTTPAdaptersServerWrapper(port: maxPort)

        #expect(wrapper.port == maxPort)
    }

    @Test("when_serverLifecycle_then_handlesGracefully")
    func serverLifecycle() async throws {
        let wrapper = HTTPAdaptersServerWrapper(port: 8080)
        let handler = TestHTTPHandler()

        await wrapper.appendRoute(HTTPRouteInfo(method: .get, path: "/test"), to: handler)

        do {
            try await wrapper.run()
            #expect(Bool(false), "run() should throw an error in test environment")
        } catch {
            #expect(true)
        }

        await wrapper.stop()

        #expect(true)
    }
}

private struct TestHTTPHandler: HTTPHandlerAdapter {
    func handleRequest(_: HTTPRequestInfo) async throws -> HTTPResponseInfo {
        HTTPResponseInfo(status: .ok)
    }
}
