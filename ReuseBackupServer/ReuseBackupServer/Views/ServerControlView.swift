import SwiftUI

/// サーバーコントロール用のビューコンポーネント
///
/// サーバーの開始・停止操作を行うためのボタンとヘルプテキストを提供します。
struct ServerControlView: View {
    /// サーバー管理用のViewModel
    @ObservedObject var viewModel: ServerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // メインコントロールボタン
            Button(action: {
                Task {
                    if viewModel.isRunning {
                        await viewModel.stopServer()
                    } else {
                        await viewModel.startServer()
                    }
                }
            }) {
                HStack {
                    Image(systemName: buttonIcon)
                    Text(controlButtonTitle)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonColor)
                .cornerRadius(12)
            }
            .disabled(isControlButtonDisabled)

            // ステータス更新ボタン
            if !viewModel.isRunning {
                Button(action: {
                    viewModel.refreshServerStatus()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("状態を更新")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }

            // ヘルプテキスト
            Text(helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// ボタンのアイコンを返す
    private var buttonIcon: String {
        switch viewModel.serverStatus {
        case .stopped, .error:
            return "play.fill"
        case .starting:
            return "hourglass"
        case .running:
            return "stop.fill"
        case .stopping:
            return "hourglass"
        }
    }

    /// ボタンの背景色を返す
    private var buttonColor: Color {
        if isControlButtonDisabled {
            return .gray
        }

        switch viewModel.serverStatus {
        case .stopped, .error:
            return .green
        case .starting:
            return .orange
        case .running:
            return .red
        case .stopping:
            return .orange
        }
    }

    /// サーバーコントロールボタンのタイトル
    private var controlButtonTitle: String {
        switch viewModel.serverStatus {
        case .stopped, .error:
            return "サーバー開始"
        case .starting:
            return "開始中..."
        case .running:
            return "サーバー停止"
        case .stopping:
            return "停止中..."
        }
    }

    /// サーバーコントロールボタンが無効かどうか
    private var isControlButtonDisabled: Bool {
        return viewModel.serverStatus == .starting || viewModel.serverStatus == .stopping
    }

    /// 状況に応じたヘルプテキストを返す
    private var helpText: String {
        switch viewModel.serverStatus {
        case .stopped:
            return "サーバーを開始すると、クライアントアプリから接続できるようになります"
        case .starting:
            return "サーバーを開始しています..."
        case .running:
            return "サーバーが稼働中です。クライアントアプリから接続可能です"
        case .stopping:
            return "サーバーを停止しています..."
        case .error:
            return "エラーが発生しました。再度開始を試してください"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 停止中の状態
        ServerControlView(viewModel: {
            let vm = ServerViewModel()
            return vm
        }())

        // 稼働中の状態
    }
    .padding()
}
