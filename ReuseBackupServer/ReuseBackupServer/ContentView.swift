//
//  ContentView.swift
//  ReuseBackupServer
//
//  Created by haludoll on 2025/07/01.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var httpServer = HTTPServer()
    
    var body: some View {
        VStack(spacing: 20) {
            // ヘッダー
            VStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                
                Text("ReuseBackup Server")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("古いiPhoneをバックアップサーバーに")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // サーバーステータス
            VStack(spacing: 12) {
                Text("サーバーステータス")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(statusText)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Text("ポート: 8080")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            
            Spacer()
            
            // コントロールボタン
            VStack(spacing: 16) {
                if httpServer.isRunning {
                    Button(action: {
                        Task {
                            await httpServer.stopServer()
                        }
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("サーバーを停止")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        Task {
                            await httpServer.startServer()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("サーバーを開始")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                Text("サーバーが起動すると、クライアントアプリからメッセージを受信できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch httpServer.serverStatus {
        case .running:
            return .green
        case .starting, .stopping:
            return .orange
        case .error:
            return .red
        case .stopped:
            return .gray
        }
    }
    
    private var statusText: String {
        switch httpServer.serverStatus {
        case .running:
            return "稼働中"
        case .starting:
            return "開始中..."
        case .stopping:
            return "停止中..."
        case .error(let message):
            return "エラー: \(message)"
        case .stopped:
            return "停止中"
        }
    }
}

#Preview {
    ContentView()
}
