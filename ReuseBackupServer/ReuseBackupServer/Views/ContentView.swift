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
            ServerStatusView(viewModel: viewModel)
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)

            Spacer()

            // コントロールボタン
            ServerControlView(viewModel: viewModel)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
