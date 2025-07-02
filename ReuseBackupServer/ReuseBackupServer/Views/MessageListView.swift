import SwiftUI

struct MessageListView: View {
    @ObservedObject var messageManager: MessageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Received Messages")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    messageManager.clearMessages()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if messageManager.messages.isEmpty {
                Text("No messages received")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .default).italic())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List(messageManager.messages.indices, id: \.self) { index in
                    Text(messageManager.messages[index])
                        .padding(.vertical, 2)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}
