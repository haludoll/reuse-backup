//
//  ServerStatusChecker.swift
//  ReuseBackupClient
//
//  Created by haludoll on 2025/07/08.
//

import APISharedModels
import Foundation

@MainActor
final class ServerStatusChecker: ObservableObject {
    @Published var isOnline = false
    @Published var isChecking = false
    @Published var serverStatus: Components.Schemas.ServerStatus?

    private let httpClient = HTTPClient()

    func checkStatus(endpoint: String) async {
        guard let url = URL(string: endpoint) else {
            isOnline = false
            return
        }

        isChecking = true

        do {
            let status = try await httpClient.checkServerStatus(baseURL: url)
            serverStatus = status
            isOnline = true
        } catch {
            serverStatus = nil
            isOnline = false
        }

        isChecking = false
    }
}
