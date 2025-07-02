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
            return .green
        case .starting, .stopping:
            return .orange
        case .error:
            return .red
        case .stopped:
            return .gray
        }
    }

    /// サーバーステータスの表示用文字列
    private var statusDisplayText: String {
        switch viewModel.serverStatus {
        case .stopped:
            return "停止中"
        case .starting:
            return "開始中..."
        case .running:
            return "稼働中"
        case .stopping:
            return "停止中..."
        case let .error(message):
            return "エラー: \(message)"
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
