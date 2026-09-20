import XCTest
@testable import NamingCore

final class NamingCoreTests: XCTestCase {
    func testCanonicalNamesRoundTripWithEmptyOptionalSlotAndExtensions() throws {
        for (name, folder) in [("2026-09-19_广州旅行_沙面_傍晚", true), ("2026-09-19_旅行__精选.jpg", false), ("2024-02-29_校园", true)] {
            let parsed = Naming.parse(name, isDirectory: folder)
            XCTAssertTrue(parsed.compliant, name)
            XCTAssertEqual(try parsed.fields.name(extension: folder ? "" : "jpg"), name)
        }
        XCTAssertEqual(Naming.parse("2026-09-19_旅行__精选.jpg", isDirectory: false).fields.secondary, "")
    }
    func testDatesAndReservedCharactersAreValidated() throws {
        for fields in [Fields("2026", "02", "29", "旅行"), Fields("1900", "02", "29", "旅行"), Fields("2026", "13", "01", "旅行"), Fields("2026", "09", "00", "旅行"), Fields("", "", "", ""), Fields("2026", "09", "20", "a_b"), Fields("2026", "09", "20", "a/b")] {
            XCTAssertFalse(fields.errors.isEmpty)
            XCTAssertThrowsError(try fields.name())
        }
        XCTAssertEqual(try Fields("2000", "2", "29", " 旅行 ", "", "精选").name(), "2000-02-29_旅行__精选")
    }
    func testNoncanonicalNameRetainsOnlyDateCandidateAndNeverInventsDate() {
        let parsed = Naming.parse("2026.9.2 广州旅行", isDirectory: true)
        XCTAssertFalse(parsed.compliant)
        XCTAssertEqual(parsed.fields.year, "2026")
        XCTAssertEqual(parsed.fields.primary, "广州旅行")
        XCTAssertEqual(Naming.parse("未整理照片", isDirectory: true).fields.year, "")
        XCTAssertFalse(Naming.parse("2026-02-30_旅行", isDirectory: true).compliant)
        XCTAssertFalse(Naming.parse("2026-09-20_旅行_", isDirectory: true).compliant)
        XCTAssertEqual(Naming.display("a__b"), "a  b")
    }
    func testOrdinaryUnicodeTitlesRemainValidInOptimizedBuilds() {
        for title in ["旅行", "abc", "Café", "日常 📷", "a-b"] {
            XCTAssertTrue(Fields("2026", "09", "20", title).errors.isEmpty, title)
        }
        for date in ["abcd", "２０２６", "٢٠٢٦"] {
            XCTAssertFalse(Fields(date, "09", "20", "旅行").errors.isEmpty)
        }
    }
}

final class FileOperationsTests: XCTestCase {
    var root: URL!
    var engine: RenameEngine!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("PhotoNamingTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        engine = try RenameEngine(journalDirectory: root.appendingPathComponent("journal"))
    }
    override func tearDownWithError() throws { if let root { try FileManager.default.removeItem(at: root) } }
    func file(_ name: String, text: String = "original") throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        return url
    }
    func item(_ url: URL) throws -> Item { try XCTUnwrap(Scanner.scan([url]).items.first) }
    let fields = Fields("2026", "09", "20", "旅行")

    func testScanDeduplicatesAndSkipsSymlinksAndPackages() throws {
        let source = try file("folder/a.jpg")
        let folder = source.deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link"), withDestinationURL: source)
        _ = try file("folder/Test.app/Contents/inside")
        let shallow = Scanner.scan([folder, folder])
        XCTAssertEqual(shallow.items.count, 1)
        let deep = Scanner.scan([folder, source], options: ScanOptions(folders: true, files: true))
        XCTAssertEqual(Set(deep.items.map { $0.url.lastPathComponent }), Set(["folder", "a.jpg"]))
        XCTAssertGreaterThanOrEqual(deep.skipped.count, 2)
    }
    func testPreviewDoesNotRenameAndExecutionPreservesBytesAndUndoSurvivesRestart() throws {
        let source = try file("old.jpg")
        let changes = try engine.preview([(try item(source), fields)])
        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let batch = try engine.execute(changes)
        let target = root.appendingPathComponent("2026-09-20_旅行.jpg")
        XCTAssertEqual(batch.records.filter { $0.state == "done" }.count, 1)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        let restarted = try RenameEngine(journalDirectory: root.appendingPathComponent("journal"))
        let saved = try XCTUnwrap(restarted.latestUndoable())
        _ = try restarted.undo(saved)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
    func testExistingAndBatchDuplicateTargetsAreBlocked() throws {
        let a = try file("a.jpg")
        let b = try file("b.jpg")
        XCTAssertThrowsError(try engine.preview([(try item(a), fields), (try item(b), fields)]))
        let target = try file("2026-09-20_旅行.jpg", text: "keep")
        XCTAssertThrowsError(try engine.preview([(try item(a), fields)]))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "keep")
    }
    func testExternalReplacementAfterPreviewIsNeverRenamed() throws {
        let source = try file("a.jpg")
        let changes = try engine.preview([(try item(source), fields)])
        try FileManager.default.moveItem(at: source, to: root.appendingPathComponent("moved.jpg"))
        _ = try file("a.jpg", text: "replacement")
        XCTAssertThrowsError(try engine.execute(changes))
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "replacement")
    }
    func testConflictCreatedAfterPreviewIsNeverOverwritten() throws {
        let source = try file("a.jpg")
        let changes = try engine.preview([(try item(source), fields)])
        _ = try file("2026-09-20_旅行.jpg", text: "keep")
        XCTAssertThrowsError(try engine.execute(changes))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testParentAndChildRenameAndUndoInSafeOrder() throws {
        let source = try file("old-folder/old.jpg")
        let parent = source.deletingLastPathComponent()
        let changes = try engine.preview([(try item(parent), fields), (try item(source), fields)])
        let batch = try engine.execute(changes)
        let final = root.appendingPathComponent("2026-09-20_旅行/2026-09-20_旅行.jpg")
        XCTAssertEqual(try String(contentsOf: final, encoding: .utf8), "original")
        XCTAssertEqual(batch.records.count, 2)
        _ = try engine.undo(batch)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
    }
    func testUndoRefusesToOverwriteNewSource() throws {
        let source = try file("a.jpg")
        let batch = try engine.execute(engine.preview([(try item(source), fields)]))
        _ = try file("a.jpg", text: "new")
        let undone = try engine.undo(batch)
        XCTAssertEqual(undone.records.filter { $0.state == "done" }.count, 1)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "new")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("2026-09-20_旅行.jpg").path))
    }
    func testExplicitChildFolderIsIncludedEvenWhenRecursionOnlyIncludesFiles() throws {
        let photo = try file("parent/child/photo.jpg")
        let child = photo.deletingLastPathComponent()
        let parent = child.deletingLastPathComponent()
        let result = Scanner.scan([parent, child], options: ScanOptions(files: true))
        XCTAssertEqual(Set(result.items.map { $0.url.path }), Set([parent.path, child.path, photo.path]))
    }
    func testPartialFailureReportsSuccessfulAndFailedItemsSeparately() throws {
        let locked = try file("a.jpg"), normal = try file("b.jpg")
        let changes = try engine.preview([(try item(locked), fields), (try item(normal), Fields("2026", "09", "20", "校园"))])
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: locked.path) }
        let batch = try engine.execute(changes)
        XCTAssertEqual(batch.completed, 1)
        XCTAssertEqual(batch.records.filter { $0.state == "failed" }.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: locked.path))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("2026-09-20_校园.jpg"), encoding: .utf8), "original")
    }
    func testInterruptedJournalIsRecoveredFromIdentity() throws {
        let source = try file("old.jpg")
        var batch = try engine.execute(engine.preview([(try item(source), fields)]))
        batch.records[0].state = "pending"
        try JSONEncoder().encode(batch).write(to: root.appendingPathComponent("journal/" + batch.id.uuidString + ".json"))
        let restarted = try RenameEngine(journalDirectory: root.appendingPathComponent("journal"))
        let recovered = try XCTUnwrap(restarted.latestUndoable())
        XCTAssertEqual(recovered.completed, 1)
        _ = try restarted.undo(recovered)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testParentRenameRelocatesUnselectedDescendants() throws {
        let child = try file("folder/a.jpg")
        let batch = try engine.execute(engine.preview([(try item(child.deletingLastPathComponent()), fields)]))
        let mapped = RenameEngine.relocated(child, batch: batch)
        XCTAssertEqual(mapped, root.appendingPathComponent("2026-09-20_旅行/a.jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mapped.path))
        let undone = try engine.undo(batch)
        XCTAssertEqual(RenameEngine.relocated(mapped, batch: undone, undo: true), child)
    }
    func testNoRenameIfJournalCannotBeSaved() throws {
        let source = try file("old.jpg")
        let changes = try engine.preview([(try item(source), fields)])
        let directory = root.appendingPathComponent("journal")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        XCTAssertThrowsError(try engine.execute(changes))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
}
