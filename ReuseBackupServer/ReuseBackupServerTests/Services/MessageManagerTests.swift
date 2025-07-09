import Foundation
import Testing

@testable import ReuseBackupServer

@Suite("MessageManager Tests")
@MainActor
struct MessageManagerTests {
    @Test("when_init_then_messagesArrayIsEmpty")
    func initialization() async throws {
        let messageManager = MessageManager()

        #expect(messageManager.messages.isEmpty)
        #expect(messageManager.getMessages().isEmpty)
    }

    @Test("when_addMessage_then_messageIsAdded")
    func testAddMessage() async throws {
        let messageManager = MessageManager()
        let testMessage = "Test message"

        messageManager.addMessage(testMessage)

        #expect(messageManager.messages.count == 1)
        #expect(messageManager.messages[0] == testMessage)
        #expect(messageManager.getMessages().count == 1)
        #expect(messageManager.getMessages()[0] == testMessage)
    }

    @Test("when_addMultipleMessages_then_allMessagesAreAdded")
    func addMultipleMessages() async throws {
        let messageManager = MessageManager()
        let messages = ["Message 1", "Message 2", "Message 3"]

        for message in messages {
            messageManager.addMessage(message)
        }

        #expect(messageManager.messages.count == 3)
        #expect(messageManager.getMessages().count == 3)

        for (index, message) in messages.enumerated() {
            #expect(messageManager.messages[index] == message)
            #expect(messageManager.getMessages()[index] == message)
        }
    }

    @Test("when_clearMessages_then_messagesArrayIsEmpty")
    func testClearMessages() async throws {
        let messageManager = MessageManager()

        messageManager.addMessage("Test message 1")
        messageManager.addMessage("Test message 2")

        #expect(messageManager.messages.count == 2)

        messageManager.clearMessages()

        #expect(messageManager.messages.isEmpty)
        #expect(messageManager.getMessages().isEmpty)
    }

    @Test("when_addEmptyMessage_then_emptyMessageIsAdded")
    func addEmptyMessage() async throws {
        let messageManager = MessageManager()

        messageManager.addMessage("")

        #expect(messageManager.messages.count == 1)
        #expect(messageManager.messages[0] == "")
        #expect(messageManager.getMessages()[0] == "")
    }

    @Test("when_addLongMessage_then_longMessageIsAdded")
    func addLongMessage() async throws {
        let messageManager = MessageManager()
        let longMessage = String(repeating: "a", count: 1000)

        messageManager.addMessage(longMessage)

        #expect(messageManager.messages.count == 1)
        #expect(messageManager.messages[0] == longMessage)
        #expect(messageManager.getMessages()[0] == longMessage)
    }

    @Test("when_addSpecialCharacters_then_specialCharactersAreAdded")
    func addSpecialCharacters() async throws {
        let messageManager = MessageManager()
        let specialMessage = "🚀 Hello World! 日本語 @#$%^&*()_+-=[]{}|;:,.<>?"

        messageManager.addMessage(specialMessage)

        #expect(messageManager.messages.count == 1)
        #expect(messageManager.messages[0] == specialMessage)
        #expect(messageManager.getMessages()[0] == specialMessage)
    }

    @Test("when_addAndClearRepeated_then_behaviorIsConsistent")
    func addAndClearRepeated() async throws {
        let messageManager = MessageManager()

        for i in 1 ... 3 {
            messageManager.addMessage("Message \(i)")
            #expect(messageManager.messages.count == i)

            messageManager.clearMessages()
            #expect(messageManager.messages.isEmpty)
        }
    }

    @Test("when_getMessages_then_returnsCurrentMessages")
    func testGetMessages() async throws {
        let messageManager = MessageManager()
        let testMessages = ["First", "Second", "Third"]

        for message in testMessages {
            messageManager.addMessage(message)
        }

        let retrievedMessages = messageManager.getMessages()

        #expect(retrievedMessages.count == testMessages.count)

        for (index, message) in testMessages.enumerated() {
            #expect(retrievedMessages[index] == message)
        }
    }

    @Test("when_messagesModified_then_publishedPropertyUpdates")
    func publishedPropertyUpdates() async throws {
        let messageManager = MessageManager()

        let initialCount = messageManager.messages.count
        #expect(initialCount == 0)

        messageManager.addMessage("Test message")

        let afterAddCount = messageManager.messages.count
        #expect(afterAddCount == 1)

        messageManager.clearMessages()

        let afterClearCount = messageManager.messages.count
        #expect(afterClearCount == 0)
    }

    @Test("when_manyMessagesAdded_then_allMessagesAreStored")
    func manyMessages() async throws {
        let messageManager = MessageManager()
        let messageCount = 100

        for i in 1 ... messageCount {
            messageManager.addMessage("Message \(i)")
        }

        #expect(messageManager.messages.count == messageCount)
        #expect(messageManager.getMessages().count == messageCount)

        for i in 1 ... messageCount {
            #expect(messageManager.messages[i - 1] == "Message \(i)")
        }
    }
}
