import SwiftUI
import APISharedModels

struct MessageSendView: View {
    @StateObject private var viewModel = MessageSendViewModel()
    @State private var messageText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Server Status
                HStack {
                    Image(systemName: connectionStatusIcon)
                        .foregroundColor(connectionStatusColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接続ステータス: \(connectionStatusText)")
                            .foregroundColor(connectionStatusColor)
                            .font(.headline)
                        
                        if let serverURL = viewModel.serverURL {
                            Text("サーバー: \(serverURL.absoluteString)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("再接続") {
                        Task {
                            await viewModel.discoverServer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.connectionStatus == .connecting)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Message Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("メッセージ")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(messageText.count)/1000")
                            .font(.caption)
                            .foregroundColor(messageText.count > 1000 ? .red : .secondary)
                    }
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(messageText.count > 1000 ? Color.red : Color(.systemGray4), lineWidth: 1)
                        )
                    
                    if messageText.count > 1000 {
                        Text("⚠️ メッセージは1000文字以内で入力してください")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Send Button
                Button(action: {
                    Task {
                        await viewModel.sendMessage(messageText)
                        if viewModel.lastResponse?.received == true {
                            messageText = ""
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text(viewModel.isSending ? "送信中..." : "メッセージ送信")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSendMessage ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!canSendMessage)
                
                // Status Messages
                if let lastResponse = viewModel.lastResponse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最後の応答:")
                            .font(.headline)
                        Text("ステータス: \(lastResponse.status.rawValue)")
                        Text("受信: \(lastResponse.received ? "成功" : "失敗")")
                        Text(
                            "サーバー時刻: \(DateFormatter.iso8601.string(from: lastResponse.serverTimestamp!))"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("メッセージ送信")
            .task {
                await viewModel.discoverServer()
            }
            .refreshable {
                await viewModel.discoverServer()
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
                Button("再試行") {
                    Task {
                        await viewModel.discoverServer()
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
    
    private var canSendMessage: Bool {
        viewModel.isConnected && 
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        messageText.count <= 1000 &&
        !viewModel.isSending
    }
    
    private var connectionStatusText: String {
        switch viewModel.connectionStatus {
        case .disconnected:
            return "未接続"
        case .connecting:
            return "接続中..."
        case .connected:
            return "接続済み"
        case .error:
            return "接続エラー"
        }
    }
    
    private var connectionStatusColor: Color {
        switch viewModel.connectionStatus {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
    
    private var connectionStatusIcon: String {
        switch viewModel.connectionStatus {
        case .disconnected:
            return "circle"
        case .connecting:
            return "circle.dotted"
        case .connected:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

#Preview {
    MessageSendView()
}
