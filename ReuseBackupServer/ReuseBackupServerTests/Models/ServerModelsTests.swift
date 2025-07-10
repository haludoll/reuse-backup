//
//  ServerModelsTests.swift
//  ReuseBackupServerTests
//
//  Created by haludoll on 2025/07/01.
//

import Foundation
@testable import ReuseBackupServer
import Testing

@Suite("ServerModels Tests")
struct ServerModelsTests {
    @Test("when_serverStatusStopped_then_descriptionIsCorrect")
    func serverStatusStoppedDescription() async throws {
        let status = ServerStatus.stopped
        #expect(status.description == "stopped")
    }

    @Test("when_serverStatusStarting_then_descriptionIsCorrect")
    func serverStatusStartingDescription() async throws {
        let status = ServerStatus.starting
        #expect(status.description == "starting")
    }

    @Test("when_serverStatusRunning_then_descriptionIsCorrect")
    func serverStatusRunningDescription() async throws {
        let status = ServerStatus.running
        #expect(status.description == "running")
    }

    @Test("when_serverStatusStopping_then_descriptionIsCorrect")
    func serverStatusStoppingDescription() async throws {
        let status = ServerStatus.stopping
        #expect(status.description == "stopping")
    }

    @Test("when_serverStatusError_then_descriptionIsCorrect")
    func serverStatusErrorDescription() async throws {
        let errorMessage = "Test error message"
        let status = ServerStatus.error(errorMessage)
        #expect(status.description == "error")
    }

    @Test("when_serverStatusEquality_then_equalityWorksCorrectly")
    func serverStatusEquality() async throws {
        #expect(ServerStatus.stopped == ServerStatus.stopped)
        #expect(ServerStatus.running == ServerStatus.running)
        #expect(ServerStatus.error("test") == ServerStatus.error("test"))
        #expect(ServerStatus.stopped != ServerStatus.running)
        #expect(ServerStatus.error("test1") != ServerStatus.error("test2"))
    }

    @Test("when_serverStatusEqualityAcrossTypes_then_equalityWorksCorrectly")
    func serverStatusEqualityAcrossTypes() async throws {
        let stopped = ServerStatus.stopped
        let starting = ServerStatus.starting
        let running = ServerStatus.running
        let stopping = ServerStatus.stopping
        let error = ServerStatus.error("Test error")

        #expect(stopped != starting)
        #expect(stopped != running)
        #expect(stopped != stopping)
        #expect(stopped != error)

        #expect(starting != running)
        #expect(starting != stopping)
        #expect(starting != error)

        #expect(running != stopping)
        #expect(running != error)

        #expect(stopping != error)
    }

    @Test("when_serverStatusWithEmptyErrorMessage_then_descriptionIsStillError")
    func serverStatusWithEmptyErrorMessage() async throws {
        let status = ServerStatus.error("")
        #expect(status.description == "error")
    }

    @Test("when_serverStatusWithLongErrorMessage_then_descriptionIsStillError")
    func serverStatusWithLongErrorMessage() async throws {
        let longErrorMessage = String(repeating: "error", count: 100)
        let status = ServerStatus.error(longErrorMessage)
        #expect(status.description == "error")
    }

    @Test("when_serverStatusWithSpecialCharacters_then_descriptionIsStillError")
    func serverStatusWithSpecialCharacters() async throws {
        let specialErrorMessage = "🚀 Error with special characters! 日本語 @#$%"
        let status = ServerStatus.error(specialErrorMessage)
        #expect(status.description == "error")
    }

    @Test("when_allServerStatusCases_then_descriptionsAreDistinct")
    func allServerStatusDescriptionsAreDistinct() async throws {
        let descriptions = [
            ServerStatus.stopped.description,
            ServerStatus.starting.description,
            ServerStatus.running.description,
            ServerStatus.stopping.description,
            ServerStatus.error("test").description,
        ]

        let uniqueDescriptions = Set(descriptions)

        #expect(uniqueDescriptions.count == descriptions.count)
        #expect(uniqueDescriptions.contains("stopped"))
        #expect(uniqueDescriptions.contains("starting"))
        #expect(uniqueDescriptions.contains("running"))
        #expect(uniqueDescriptions.contains("stopping"))
        #expect(uniqueDescriptions.contains("error"))
    }

    @Test("when_serverStatusPattern_then_matchesCorrectly")
    func serverStatusPatternMatching() async throws {
        let errorMessage = "Test error"
        let status = ServerStatus.error(errorMessage)

        switch status {
        case let .error(message):
            #expect(message == errorMessage)
        default:
            #expect(Bool(false), "Should match error case")
        }
    }

    @Test("when_serverStatusLifecycleTransitions_then_statusChangesAppropriately")
    func serverStatusLifecycleTransitions() async throws {
        var status = ServerStatus.stopped
        #expect(status.description == "stopped")

        status = ServerStatus.starting
        #expect(status.description == "starting")

        status = ServerStatus.running
        #expect(status.description == "running")

        status = ServerStatus.stopping
        #expect(status.description == "stopping")

        status = ServerStatus.stopped
        #expect(status.description == "stopped")
    }
}
