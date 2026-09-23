//
//  NetworkMonitor.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Combine
import Foundation
import Network

/// Publishes whether the device is online (`NWPathMonitor`).
/// Launching with `-simulateOffline` forces offline, which UI tests and the demo use.
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let forcedOffline: Bool

    init(forcedOffline: Bool = AppConfig.hasLaunchArgument(AppConfig.LaunchArgument.simulateOffline)) {
        self.forcedOffline = forcedOffline
        isOnline = !forcedOffline
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isOnline = path.status == .satisfied && !self.forcedOffline
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}
