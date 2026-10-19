import Foundation

public protocol RecentRepositoriesStore: AnyObject {
    func lastUsedDates() -> [String: Date]
    func markUsed(_ repositoryID: String, at date: Date)
}

public final class UserDefaultsRecentRepositoriesStore: RecentRepositoriesStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "recentRepositories") {
        self.defaults = defaults
        self.key = key
    }

    public func lastUsedDates() -> [String: Date] {
        let stored = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        return stored.mapValues(Date.init(timeIntervalSince1970:))
    }

    public func markUsed(_ repositoryID: String, at date: Date) {
        var stored = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        stored[repositoryID] = date.timeIntervalSince1970
        defaults.set(stored, forKey: key)
    }
}
