//
//  RouteStorageManager.swift
//  OmniTAKMobile
//
//  Persistence layer for route planning data
//

import Foundation

class RouteStorageManager {
    static let shared = RouteStorageManager()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Storage keys
    private let routesKey = "com.omnitak.routes.all"

    private init() {}

    // MARK: - Load Routes

    func loadRoutes() -> [Route] {
        guard let data = defaults.data(forKey: routesKey) else { return [] }
        return (try? decoder.decode([Route].self, from: data)) ?? []
    }

    // MARK: - Save Route

    func saveRoute(_ route: Route) {
        var routes = loadRoutes()

        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
        } else {
            routes.insert(route, at: 0)
        }

        saveAllRoutes(routes)
    }

    // MARK: - Delete Route

    func deleteRoute(_ route: Route) {
        var routes = loadRoutes()
        routes.removeAll { $0.id == route.id }
        saveAllRoutes(routes)
    }

    // MARK: - Save All Routes

    private func saveAllRoutes(_ routes: [Route]) {
        if let data = try? encoder.encode(routes) {
            defaults.set(data, forKey: routesKey)
        }
    }

    // MARK: - Clear All

    func clearAllData() {
        defaults.removeObject(forKey: routesKey)
    }
}
