//
//  ContentView.swift
//  ReuseBackupClient
//
//  Created by haludoll on 2025/07/01.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MediaUploadView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("写真・動画")
                }

            MessageSendView()
                .tabItem {
                    Image(systemName: "message")
                    Text("メッセージ")
                }

            ServerDiscoveryView()
                .tabItem {
                    Image(systemName: "network")
                    Text("サーバー検索")
                }
        }
    }
}

#Preview {
    ContentView()
}
