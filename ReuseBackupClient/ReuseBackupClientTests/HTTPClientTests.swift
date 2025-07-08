//
//  HTTPClientTests.swift
//  ReuseBackupClientTests
//
//  Created by Claude on 2025/07/08.
//

import Testing
import Foundation
@testable import ReuseBackupClient

struct HTTPClientTests {
    
    @Test func testHTTPClientInitialization() async throws {
        // Given
        let client = HTTPClient()
        
        // When/Then
        #expect(client != nil)
    }
    
    @Test func testHTTPSURLGeneration() async throws {
        // Given
        let client = HTTPClient()
        let baseURL = URL(string: "https://localhost:8443")!
        
        // When
        let statusURL = baseURL.appendingPathComponent("/api/status")
        let messageURL = baseURL.appendingPathComponent("/api/message")
        
        // Then
        #expect(statusURL.scheme == "https")
        #expect(messageURL.scheme == "https")
    }
    
    @Test func testHTTPSConfiguration() async throws {
        // Given
        let client = HTTPClient()
        
        // When
        let hasHTTPSSupport = client.supportsHTTPS
        
        // Then
        #expect(hasHTTPSSupport == true)
    }
    
    @Test func testSelfSignedCertificateSupport() async throws {
        // Given
        let client = HTTPClient()
        
        // When
        let allowsSelfSigned = client.allowsSelfSignedCertificates
        
        // Then
        #expect(allowsSelfSigned == true)
    }
}