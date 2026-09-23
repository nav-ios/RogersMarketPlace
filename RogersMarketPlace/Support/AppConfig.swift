//
//  AppConfig.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

/// The few app-wide identifiers, so no string is typed in more than one place.
enum AppConfig {
    static let keychainService = "com.navios.RogersMarketPlace"
    static let databaseFileName = "marketplace.sqlite"
    static let currencyCode = "CAD"
    static let categories = ["Electronics", "Furniture", "Fashion", "Home", "Sports", "Other"]

    enum LaunchArgument {
        static let resetState = "-resetState"
        static let simulateOffline = "-simulateOffline"
    }

    static func hasLaunchArgument(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }
}
