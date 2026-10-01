import Foundation
import SwiftData
import os

/// How the session-history database opened this launch.
enum HistoryStoreHealth: Equatable {
    /// Opened normally.
    case normal
    /// The existing database couldn't be opened, so it was moved aside
    /// (renamed, not deleted) and a fresh, empty one was created.
    case recoveredFresh(backupName: String)
    /// Nothing on disk could be opened. History lives in memory for this
    /// launch only, and finished sessions stay queued in the App Group so
    /// they're imported on a later, healthy launch instead of being lost.
    case memoryOnly
}

/// Opens the SwiftData container for session history without ever crashing
/// the app. Before this, a store that failed to open (for example after a
/// broken migration in a future update) crashed on every launch.
///
/// Fallbacks, in order:
/// 1. Open the store normally.
/// 2. If protected data is available (the phone has been unlocked since it
///    booted), move the store files aside and start a fresh one. Moving
///    rather than deleting keeps the old data recoverable.
/// 3. Otherwise, or if that also fails, use an in-memory store.
///
/// Step 2 is skipped while protected data is unavailable: before the first
/// unlock after a reboot, iOS refuses to open the file at all, and moving a
/// perfectly good store aside then would look like data loss to the user.
enum HistoryContainer {
    private static let logger = Logger(subsystem: "com.aarontilley.pomodoro", category: "History")
    private static let schema = Schema([CompletedSession.self])

    /// `storeURL` is nil for SwiftData's default location; tests pass a
    /// temporary file.
    static func open(
        storeURL: URL? = nil,
        protectedDataAvailable: Bool,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> (container: ModelContainer, health: HistoryStoreHealth) {
        let config = storeURL.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema)

        do {
            return (try ModelContainer(for: schema, configurations: config), .normal)
        } catch {
            logger.error("History store failed to open: \(String(describing: error), privacy: .public)")
        }

        if protectedDataAvailable,
           let backupName = moveStoreAside(at: config.url, fileManager: fileManager, now: now) {
            do {
                let container = try ModelContainer(for: schema, configurations: config)
                logger.notice("History store recreated; old files kept as \(backupName, privacy: .public)")
                return (container, .recoveredFresh(backupName: backupName))
            } catch {
                logger.error("Fresh history store also failed to open: \(String(describing: error), privacy: .public)")
            }
        }

        return (inMemoryContainer(), .memoryOnly)
    }

    /// Renames the store and its SQLite side files (-shm, -wal) to
    /// "<name>.broken-<timestamp>…" in the same folder. Returns the new base
    /// name, or nil if there was no store file or the move failed.
    static func moveStoreAside(at url: URL, fileManager: FileManager = .default, now: Date = Date()) -> String? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let backupName = "\(url.lastPathComponent).broken-\(Int(now.timeIntervalSince1970))"
        let folder = url.deletingLastPathComponent()
        do {
            for suffix in ["", "-shm", "-wal"] {
                let source = URL(fileURLWithPath: url.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try fileManager.moveItem(at: source, to: folder.appendingPathComponent(backupName + suffix))
            }
            return backupName
        } catch {
            logger.error("Couldn't move history store aside: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func inMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // An in-memory store never touches the disk, so none of the failures
        // above can happen here. If even this fails, SwiftData itself is
        // unusable and there is nothing left to fall back to.
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("In-memory history store failed to open: \(error)")
        }
    }
}
