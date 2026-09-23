//
//  RogersMarketPlaceApp.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import SwiftUI

@main
struct RogersMarketPlaceApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var network = NetworkMonitor()
    @StateObject private var viewModel: MarketplaceViewModel
    private let server: MockMarketplaceServer

    init() {
        if AppConfig.hasLaunchArgument(AppConfig.LaunchArgument.resetState) { RogersMarketPlaceApp.resetState() }

        let server = MockMarketplaceServer()
        let session = server.makeSession()
        let support = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let store = try! CoreDataListingsStore(storeURL: support.appendingPathComponent(AppConfig.databaseFileName))
        let api = APIClient(baseURL: MockMarketplaceServer.baseURL, session: session, tokenStore: KeychainTokenStore())
        let repository = MarketplaceRepository(api: api, store: store)
        let network = NetworkMonitor()

        self.server = server
        _network = StateObject(wrappedValue: network)
        _viewModel = StateObject(wrappedValue: MarketplaceViewModel(repository: repository, network: network))
    }

    var body: some Scene {
        WindowGroup {
            MarketplaceView(viewModel: viewModel)
                .onReceive(network.$isOnline) { server.isOnline = $0 }   // the in-process mock server goes down with the network
                .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.sync() } }
        }
    }

    private static func resetState() {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
        let database = AppConfig.databaseFileName
        for name in [database, database + "-shm", database + "-wal"] {
            try? FileManager.default.removeItem(at: support.appendingPathComponent(name))
        }
        KeychainTokenStore().delete()
    }
}
