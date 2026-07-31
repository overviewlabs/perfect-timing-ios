import Foundation

public enum SaveMigrator {
  public static func migrate(_ value: PlayerSaveData) -> PlayerSaveData {
    var copy = value
    copy.version = PlayerSaveData.currentVersion
    if copy.achievements.isEmpty { copy.achievements = AchievementManager.defaults }
    return copy
  }
}

public protocol PersistenceService: Sendable {
  func load() async -> PlayerSaveData
  func save(_ data: PlayerSaveData) async throws
  func resetPreservingEntitlements(_ entitlements: Set<String>) async throws
}

public actor JSONPersistenceService: PersistenceService {
  private let fileURL: URL
  private let backupURL: URL
  public init(directory: URL? = nil) {
    let base =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      .appendingPathComponent("PerfectTiming", isDirectory: true)
    self.fileURL = base.appendingPathComponent("save-v3.json")
    self.backupURL = base.appendingPathComponent("save-v3.backup.json")
  }
  public func load() async -> PlayerSaveData {
    for url in [fileURL, backupURL] {
      if let bytes = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder.pt.decode(PlayerSaveData.self, from: bytes)
      {
        return SaveMigrator.migrate(decoded)
      }
    }
    return PlayerSaveData(achievements: AchievementManager.defaults)
  }
  public func save(_ data: PlayerSaveData) async throws {
    let fm = FileManager.default
    try fm.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let bytes = try JSONEncoder.pt.encode(data)
    let temp = fileURL.appendingPathExtension("tmp")
    try bytes.write(to: temp, options: .atomic)
    if fm.fileExists(atPath: fileURL.path) {
      _ = try? fm.replaceItemAt(backupURL, withItemAt: fileURL)
    }
    if fm.fileExists(atPath: fileURL.path) { try fm.removeItem(at: fileURL) }
    try fm.moveItem(at: temp, to: fileURL)
  }
  public func resetPreservingEntitlements(_ entitlements: Set<String>) async throws {
    try await save(
      PlayerSaveData(achievements: AchievementManager.defaults, premiumEntitlements: entitlements))
  }
}

extension JSONEncoder {
  fileprivate static var pt: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
  }
}
extension JSONDecoder {
  fileprivate static var pt: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }
}
