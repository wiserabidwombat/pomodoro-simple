import XCTest
import SwiftData
@testable import Pomodoro

final class HistoryContainerTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryContainerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var storeURL: URL { folder.appendingPathComponent("history.store") }

    private func writeGarbageStore() throws {
        try Data("this is not a SQLite database".utf8).write(to: storeURL)
    }

    @MainActor
    func testHealthyStoreOpensNormally() {
        let opened = HistoryContainer.open(storeURL: storeURL, protectedDataAvailable: true)
        XCTAssertEqual(opened.health, .normal)

        let store = HistoryStore(context: opened.container.mainContext, health: opened.health)
        store.recordCompletedSession(duration: 1500)
        XCTAssertEqual(store.totalCount, 1)
        XCTAssertTrue(store.isPersistent)
    }

    @MainActor
    func testUnreadableStoreIsMovedAsideAndReplaced() throws {
        try writeGarbageStore()
        let now = Date(timeIntervalSince1970: 1_000_000)

        let opened = HistoryContainer.open(storeURL: storeURL, protectedDataAvailable: true, now: now)

        XCTAssertEqual(opened.health, .recoveredFresh(backupName: "history.store.broken-1000000"))
        let backup = folder.appendingPathComponent("history.store.broken-1000000")
        XCTAssertEqual(try Data(contentsOf: backup), Data("this is not a SQLite database".utf8),
                       "the old file is kept, not deleted")

        let store = HistoryStore(context: opened.container.mainContext, health: opened.health)
        XCTAssertEqual(store.totalCount, 0)
        store.recordCompletedSession(duration: 1500)
        XCTAssertEqual(store.totalCount, 1)
        XCTAssertTrue(store.isPersistent)
    }

    @MainActor
    func testUnreadableStoreIsLeftAloneWhileProtectedDataIsUnavailable() throws {
        try writeGarbageStore()

        let opened = HistoryContainer.open(storeURL: storeURL, protectedDataAvailable: false)

        XCTAssertEqual(opened.health, .memoryOnly)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "the store must not be moved")
        let store = HistoryStore(context: opened.container.mainContext, health: opened.health)
        XCTAssertFalse(store.isPersistent)
    }

    func testMoveAsideMovesSQLiteSideFiles() throws {
        try writeGarbageStore()
        try Data("wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        try Data("shm".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-shm"))

        let name = HistoryContainer.moveStoreAside(at: storeURL, now: Date(timeIntervalSince1970: 42))

        XCTAssertEqual(name, "history.store.broken-42")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names, ["history.store.broken-42", "history.store.broken-42-shm", "history.store.broken-42-wal"])
    }

    func testMoveAsideWithNoStoreReturnsNil() {
        XCTAssertNil(HistoryContainer.moveStoreAside(at: storeURL))
    }
}
