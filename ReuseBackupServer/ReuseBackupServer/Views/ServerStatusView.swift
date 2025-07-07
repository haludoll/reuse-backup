import SwiftUI

/// サーバーステータス表示用のビューコンポーネント
///
/// サーバーの現在の状態、アップタイム、ポート番号などの情報を表示します。
struct ServerStatusView: View {
    /// サーバー管理用のViewModel
    @ObservedObject var viewModel: ServerViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("サーバーステータス")
                .font(.headline)

            // ステータス表示
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusDisplayText)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Text("ポート: \(viewModel.port)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // エラーメッセージ表示（エラー時のみ）
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }

    /// ステータスに応じた色を返す
    private var statusColor: Color {
        switch viewModel.serverStatus {
        case .running:
            .green
        case .starting, .stopping:
            .orange
        case .error:
            .red
        case .stopped:
            .gray
        }
    }

    /// サーバーステータスの表示用文字列
    private var statusDisplayText: String {
        switch viewModel.serverStatus {
        case .stopped:
            "停止中"
        case .starting:
            "開始中..."
        case .running:
            "稼働中"
        case .stopping:
            "停止中..."
        case let .error(message):
            "エラー: \(message)"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 停止中の状態
        ServerStatusView(viewModel: {
            let vm = ServerViewModel()
            return vm
        }())

        // 稼働中の状態（プレビュー用）
        ServerStatusView(viewModel: {
            let vm = ServerViewModel()
            // 稼働中の状態
            return vm
        }())
    }
    .padding()
}
