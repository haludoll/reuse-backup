//
//  ContentView.swift
//  ReuseBackupServer
//
//  Created by haludoll on 2025/07/01.
//

import SwiftUI

/// ReuseBackupServerのメインビュー
///
/// MVVMアーキテクチャに基づいて設計されたサーバー管理画面です。
/// ServerViewModelを通じてサーバーの状態管理と操作を行います。
struct ContentView: View {
    /// サーバー管理用のViewModel
    @StateObject private var viewModel = ServerViewModel()

    var body: some View {
        VStack(spacing: 20) {
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

            ServerStatusView(viewModel: viewModel)
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)

            MessageListView(messageManager: viewModel.messageManager)

            Spacer()

            ServerControlView(viewModel: viewModel)
        }
        .padding()
        .onAppear {
            // 自動起動が有効な場合のみサーバーを起動
            if viewModel.autoStartEnabled {
                Task {
                    print("🚀 Auto-starting server on app launch...")
                    await viewModel.startServer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
