import SwiftUI
import APISharedModels

struct MessageSendView: View {
    @StateObject private var viewModel = MessageSendViewModel()
    @State private var messageText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Server Status
                Group {
                    if viewModel.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("サーバーに接続済み")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("サーバーが見つかりません")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Message Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("メッセージ")
                        .font(.headline)
                    
                    TextEditor(text: $messageText)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                // Send Button
                Button(action: {
                    Task {
                        await viewModel.sendMessage(messageText)
                        messageText = ""
                    }
                }) {
                    HStack {
                        if viewModel.isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text("メッセージ送信")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isConnected && !messageText.isEmpty && !viewModel.isSending ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!viewModel.isConnected || messageText.isEmpty || viewModel.isSending)
                
                // Status Messages
                if let lastResponse = viewModel.lastResponse {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最後の応答:")
                            .font(.headline)
                        Text("ステータス: \(lastResponse.status.rawValue)")
                        Text("受信: \(lastResponse.received ? "成功" : "失敗")")
                        Text("サーバー時刻: \(DateFormatter.iso8601.string(from: lastResponse.serverTimestamp))")
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