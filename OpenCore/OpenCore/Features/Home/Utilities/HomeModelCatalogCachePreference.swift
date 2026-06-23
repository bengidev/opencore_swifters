import Foundation

nonisolated struct ModelCatalogCachePreference: Equatable, Sendable, Codable {
    var providerID: String
    var models: [ChatModel]
    var fetchedAt: Date

    func isStale(maxAge: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > maxAge
    }
}

nonisolated protocol ModelCatalogCachePreferenceStore: Sendable {
    func cachedCatalog() -> ModelCatalogCachePreference?
    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?)
}

nonisolated struct UserDefaultsModelCatalogCachePreferenceStore: ModelCatalogCachePreferenceStore {
    private enum Key {
        static let cachedCatalog = "opencore.provider.cachedModelCatalog"
    }

    func cachedCatalog() -> ModelCatalogCachePreference? {
        guard let data = UserDefaults.standard.data(forKey: Key.cachedCatalog) else { return nil }
        return try? JSONDecoder().decode(ModelCatalogCachePreference.self, from: data)
    }

    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?) {
        guard let catalog, let data = try? JSONEncoder().encode(catalog) else {
            UserDefaults.standard.removeObject(forKey: Key.cachedCatalog)
            return
        }
        UserDefaults.standard.set(data, forKey: Key.cachedCatalog)
    }
}

nonisolated final class InMemoryModelCatalogCachePreferenceStore: ModelCatalogCachePreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storedCatalog: ModelCatalogCachePreference?

    func cachedCatalog() -> ModelCatalogCachePreference? {
        lock.lock()
        defer { lock.unlock() }
        return storedCatalog
    }

    func setCachedCatalog(_ catalog: ModelCatalogCachePreference?) {
        lock.lock()
        defer { lock.unlock() }
        storedCatalog = catalog
    }
}

nonisolated struct HomeModelCatalogCachePreferenceClient: Sendable {
    var cachedCatalog: @Sendable () -> ModelCatalogCachePreference?
    var setCachedCatalog: @Sendable (ModelCatalogCachePreference?) -> Void

    static let live = HomeModelCatalogCachePreferenceClient.wrap(UserDefaultsModelCatalogCachePreferenceStore())
    static let preview = HomeModelCatalogCachePreferenceClient.wrap(InMemoryModelCatalogCachePreferenceStore())

    static func wrap(_ store: some ModelCatalogCachePreferenceStore) -> HomeModelCatalogCachePreferenceClient {
        HomeModelCatalogCachePreferenceClient(
            cachedCatalog: { store.cachedCatalog() },
            setCachedCatalog: { store.setCachedCatalog($0) }
        )
    }
}
