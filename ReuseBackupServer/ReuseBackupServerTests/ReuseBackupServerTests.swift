//
//  ReuseBackupServerTests.swift
//  ReuseBackupServerTests
//
//  Created by haludoll on 2025/07/01.
//

import Testing
import Foundation
@testable import ReuseBackupServer

struct HTTPServerTests {
    
    @Test func test_when_server_initialized_then_status_is_stopped() async throws {
        let server = HTTPServer()
        
        #expect(server.isRunning == false)
        #expect(server.serverStatus.description == "stopped")
    }
    
    @Test func test_when_message_request_created_then_properties_are_set() async throws {
        let message = "Test message"
        let timestamp = "2025-07-01T12:00:00Z"
        
        let request = HTTPServer.MessageRequest(message: message, timestamp: timestamp)
        
        #expect(request.message == message)
        #expect(request.timestamp == timestamp)
    }
    
    @Test func test_when_message_response_created_then_properties_are_set() async throws {
        let status = "success"
        let received = true
        let serverTimestamp = "2025-07-01T12:00:01Z"
        
        let response = HTTPServer.MessageResponse(
            status: status,
            received: received,
            serverTimestamp: serverTimestamp
        )
        
        #expect(response.status == status)
        #expect(response.received == received)
        #expect(response.serverTimestamp == serverTimestamp)
    }
    
    @Test func test_when_error_response_created_then_properties_are_set() async throws {
        let status = "error"
        let error = "Invalid JSON format"
        let received = false
        
        let response = HTTPServer.ErrorResponse(
            status: status,
            error: error,
            received: received
        )
        
        #expect(response.status == status)
        #expect(response.error == error)
        #expect(response.received == received)
    }
    
    @Test func test_when_server_status_response_created_then_properties_are_set() async throws {
        let status = "running"
        let uptime = 3600
        let version = "1.0.0"
        let serverTime = "2025-07-01T12:00:00Z"
        
        let response = HTTPServer.ServerStatusResponse(
            status: status,
            uptime: uptime,
            version: version,
            serverTime: serverTime
        )
        
        #expect(response.status == status)
        #expect(response.uptime == uptime)
        #expect(response.version == version)
        #expect(response.serverTime == serverTime)
    }
    
    @Test func test_when_message_request_encoded_then_json_is_valid() async throws {
        let request = HTTPServer.MessageRequest(
            message: "Hello from client",
            timestamp: "2025-07-01T12:00:00Z"
        )
        
        let data = try JSONEncoder().encode(request)
        let decodedRequest = try JSONDecoder().decode(HTTPServer.MessageRequest.self, from: data)
        
        #expect(decodedRequest.message == request.message)
        #expect(decodedRequest.timestamp == request.timestamp)
    }
    
    @Test func test_when_server_status_descriptions_then_correct_strings() async throws {
        #expect(HTTPServer.ServerStatus.stopped.description == "stopped")
        #expect(HTTPServer.ServerStatus.starting.description == "starting")
        #expect(HTTPServer.ServerStatus.running.description == "running")
        #expect(HTTPServer.ServerStatus.stopping.description == "stopping")
        #expect(HTTPServer.ServerStatus.error("test error").description == "error")
    }
}
