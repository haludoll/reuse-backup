import SwiftUI
import Network
import APISharedModels

struct ServerDiscoveryView: View {
    @StateObject private var discoveryManager = ServerDiscoveryManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Discovery Status
                Group {
                    if discoveryManager.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("サーバーを検索中...")
                        }
                    } else {
                        HStack {
                            Image(systemName: discoveryManager.discoveredServers.isEmpty ? "magnifyingglass" : "checkmark.circle.fill")
                                .foregroundColor(discoveredServers.isEmpty ? .gray : .green)
                            Text(discoveredServers.isEmpty ? "サーバーが見つかりません" : "\(discoveredServers.count)台のサーバーが見つかりました")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Server List
                if !discoveredServers.isEmpty {
                    List(discoveredServers, id: \.endpoint) { server in
                        ServerRowView(server: server)
                            .listRowBackground(Color(.systemGray6))
                    }
                    .listStyle(PlainListStyle())
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("サーバーが見つかりません")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("ReuseBackupServerアプリが同じネットワーク上で動作していることを確認してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }
                
                Spacer()
                
                // Manual Server Entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("手動でサーバーを追加")
                        .font(.headline)
                    
                    HStack {
                        TextField("例: 192.168.1.100:8080", text: $discoveryManager.manualServerAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("追加") {
                            discoveryManager.addManualServer()
                        }
                        .disabled(discoveryManager.manualServerAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("サーバー検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("再検索") {
                        discoveryManager.startDiscovery()
                    }
                    .disabled(discoveryManager.isSearching)
                }
            }
            .task {
                discoveryManager.startDiscovery()
            }
            .alert(discoveryManager.alertTitle, isPresented: $discoveryManager.showingAlert) {
                Button("OK") { }
            } message: {
                Text(discoveryManager.alertMessage)
            }
        }
    }
    
    private var discoveredServers: [DiscoveredServer] {
        discoveryManager.discoveredServers
    }
}

struct ServerRowView: View {
    let server: DiscoveredServer
    @StateObject private var statusChecker = ServerStatusChecker()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.endpoint)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Group {
                    if statusChecker.isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: statusChecker.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(statusChecker.isOnline ? .green : .red)
                    }
                }
            }
            
            if let status = statusChecker.serverStatus {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ステータス: \(status.status.rawValue)")
                        .font(.caption)
                    Text("稼働時間: \(formatUptime(status.uptime))")
                        .font(.caption)
                    Text("バージョン: \(status.version)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await statusChecker.checkStatus(endpoint: server.endpoint)
        }
    }
    
    private func formatUptime(_ uptime: Int) -> String {
        let hours = uptime / 3600
        let minutes = (uptime % 3600) / 60
        return "\(hours)時間\(minutes)分"
    }
}

#Preview {
    ServerDiscoveryView()
}