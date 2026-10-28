import XCTest
@testable import NamingCore

final class TimeEditingTests: XCTestCase {
    let zone = TimeZone(secondsFromGMT: 8 * 3600)!
    func date(_ s: String) throws -> Date { try TimeText.parse(s, zone: zone) }
    func sample(content: Bool = true) throws -> TimeSnapshot {
        TimeSnapshot(path: "/fixture.ARW", inode: 1, device: 1, size: 10,
                     created: try date("2026:07:11 18:00:00"), modified: try date("2026:07:11 19:00:00"),
                     content: content ? try date("2026:07:11 17:43:08") : nil)
    }
    func testShiftCrossesMidnightAndKeepsIntervals() throws {
        let a = try TimePlanner.plan(sample(), request: .init(mode: .shift, fields: Set(TimeField.allCases), target: Date(), delta: 16 * 3600, zone: zone))
        XCTAssertEqual(a.content, try date("2026:07:12 09:43:08"))
        XCTAssertEqual(a.created, try date("2026:07:12 10:00:00"))
        XCTAssertEqual(a.modified, try date("2026:07:12 11:00:00"))
    }
    func testUnifyOnlyCheckedFieldsAndSyncUsesContent() throws {
        let s = try sample(), target = try date("2026:07:15 10:00:00")
        let p = try TimePlanner.plan(s, request: .init(mode: .set, fields: [.created], target: target, delta: 0, zone: zone))
        XCTAssertEqual(p.created, target); XCTAssertEqual(p.modified, s.modified); XCTAssertEqual(p.content, s.content)
        let sync = try TimePlanner.plan(s, request: .init(mode: .sync, fields: Set(TimeField.allCases), target: target, delta: 0, zone: zone))
        XCTAssertEqual(sync.created, s.content); XCTAssertEqual(sync.modified, s.content); XCTAssertEqual(sync.content, s.content)
    }
    func testMissingContentNeverInventedForSyncOrShift() throws {
        let s = try sample(content: false)
        for mode in [TimeMode.sync, .shift] {
            XCTAssertThrowsError(try TimePlanner.plan(s, request: .init(mode: mode, fields: Set(TimeField.allCases), target: Date(), delta: 1, zone: zone)))
        }
        let target = try date("2026:07:15 10:00:00")
        XCTAssertEqual(try TimePlanner.plan(s, request: .init(mode: .set, fields: [.content], target: target, delta: 0, zone: zone)).content, target)
    }
    func testTimezoneAndInvalidDates() throws {
        XCTAssertEqual(try TimeText.parse("2026:07:15 10:00:00+08:00", zone: TimeZone(secondsFromGMT: 0)!), try date("2026:07:15 10:00:00"))
        XCTAssertThrowsError(try date("2026:02:30 10:00:00"))
        XCTAssertThrowsError(try date("not a time"))
    }
}

import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

final class TimeEngineTests: XCTestCase {
    var root: URL!
    let zone = TimeZone(secondsFromGMT: 8 * 3600)!
    override func setUpWithError() throws {
        root = (ProcessInfo.processInfo.environment["PHOTO_TIME_TEST_ROOT"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory).appendingPathComponent("PhotoTimeTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func photo() throws -> URL {
        let url = root.appendingPathComponent("照片 with spaces.jpg")
        let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, context.makeImage()!, [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:07:11 17:43:08", kCGImagePropertyExifDateTimeDigitized: "2026:07:11 17:43:08"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest)); return url
    }
    func engine() throws -> TimeEngine { try TimeEngine(journalDirectory: root.appendingPathComponent("journal")) }
    func testFilesystemSyncPreservesBytesAndReadsBackCreation() throws {
        let url = try photo(), original = try Data(contentsOf: url), e = try engine()
        let s = try e.read(url, zone: zone)
        let p = try TimePlanner.plan(s, request: .init(mode: .sync, fields: [.created, .modified], target: Date(), delta: 0, zone: zone))
        XCTAssertEqual(try Data(contentsOf: url), original, "Preview must not write")
        XCTAssertTrue(try e.execute([p])[0].success)
        let after = try e.read(url, zone: zone)
        XCTAssertEqual(after.created.timeIntervalSince1970, s.content!.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(after.modified, s.content)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testContentWritePreservesUncheckedFileDatesAndPixels() throws {
        let url = try photo(), e = try engine(), s = try e.read(url, zone: zone)
        let before = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!.dataProvider!.data! as Data
        let target = try TimeText.parse("2026:07:15 10:00:00", zone: zone)
        let p = try TimePlanner.plan(s, request: .init(mode: .set, fields: [.content], target: target, delta: 0, zone: zone))
        let result = try e.execute([p]); XCTAssertTrue(result[0].success, result[0].message)
        let after = try e.read(url, zone: zone)
        XCTAssertEqual(after.content, target)
        XCTAssertEqual(floor(after.created.timeIntervalSince1970), floor(s.created.timeIntervalSince1970))
        if ProcessInfo.processInfo.environment["PHOTO_TIME_TEST_ROOT"] == nil {
            XCTAssertEqual(after.created.timeIntervalSince1970, s.created.timeIntervalSince1970, accuracy: 0.01)
        }
        XCTAssertEqual(after.modified.timeIntervalSince1970, s.modified.timeIntervalSince1970, accuracy: 0.01)
        let pixels = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!.dataProvider!.data! as Data
        XCTAssertEqual(pixels, before)
    }
    func testExternalChangeRejectedAndOtherFilesContinue() throws {
        let url = try photo(), e = try engine(), s = try e.read(url, zone: zone)
        let p = try TimePlanner.plan(s, request: .init(mode: .sync, fields: [.created], target: Date(), delta: 0, zone: zone))
        let other = root.appendingPathComponent("other.jpg"); try FileManager.default.copyItem(at: url, to: other)
        let second = try TimePlanner.plan(e.read(other, zone: zone), request: .init(mode: .sync, fields: [.created], target: Date(), delta: 0, zone: zone))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 30)], ofItemAtPath: url.path)
        let result = try e.execute([p, second]); XCTAssertFalse(result[0].success)
        XCTAssertTrue(result[0].message.contains("变化")); XCTAssertTrue(result[1].success, result[1].message)
    }
    func testCollectSkipsSymlinksAndFindsNestedMedia() throws {
        let url = try photo(), link = root.appendingPathComponent("link.jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url)
        try Data("notes".utf8).write(to: root.appendingPathComponent("note.txt"))
        let nested = root.appendingPathComponent("nested");try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(contentsOf: url).write(to: nested.appendingPathComponent("copy.jpg"))
        XCTAssertEqual(TimeEngine.collect([root]).count, 2, TimeEngine.collect([root]).map(\.path).joined(separator: "\n"))
    }
    func testVideoCreationTimeAndMediaPayloadPreserved() throws {
        let fixture = Bundle.module.url(forResource: "QuickTime", withExtension: "mov", subdirectory: "Fixtures")!
        let url = root.appendingPathComponent("视频.mov"); try FileManager.default.copyItem(at: fixture, to: url)
        // Upstream fixture has an empty mdat. Add known synthetic media bytes so
        // payload equality is meaningful rather than two empty arrays.
        var original = try Data(contentsOf: url)
        let media = Data((0..<4096).map { UInt8($0 % 251) })
        let mdatSize = UInt32(media.count + 8)
        original.replaceSubrange(original.count-8..<original.count-4, with: [UInt8((mdatSize >> 24) & 255), UInt8((mdatSize >> 16) & 255), UInt8((mdatSize >> 8) & 255), UInt8(mdatSize & 255)])
        original.append(media); try original.write(to: url)
        func payload(_ data: Data) -> Data {
            var i = 0, result = Data()
            while i + 8 <= data.count {
                let size = data[i..<i+4].reduce(0) { $0 * 256 + Int($1) }
                guard size >= 8, i + size <= data.count else { break }
                if String(data: data[i+4..<i+8], encoding: .ascii) == "mdat" { result.append(data[i+8..<i+size]) }
                i += size
            }
            return result
        }
        XCTAssertEqual(payload(original), media)
        let e = try engine(), snapshot = try e.read(url, zone: zone)
        let target = try TimeText.parse("2026:07:15 10:00:00", zone: zone)
        let plan = try TimePlanner.plan(snapshot, request: .init(mode: .set, fields: Set(TimeField.allCases), target: target, delta: 0, zone: zone))
        let result = try e.execute([plan]); XCTAssertTrue(result[0].success, result[0].message)
        let actual = try e.read(url, zone: zone)
        XCTAssertEqual(actual.content, target)
        XCTAssertEqual(actual.created.timeIntervalSince1970, target.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(payload(original), payload(try Data(contentsOf: url)))
    }
    func testShiftWritesIndependentFileDatesAndRejectsAlreadyAppliedPlan() throws {
        let url = try photo(), e = try engine(), s = try e.read(url, zone: zone)
        let plan = try TimePlanner.plan(s, request: .init(mode: .shift, fields: Set(TimeField.allCases), target: Date(), delta: 16 * 3600, zone: zone))
        let first = try e.execute([plan]); XCTAssertTrue(first[0].success, first[0].message)
        let actual = try e.read(url, zone: zone)
        XCTAssertEqual(actual.content, s.content!.addingTimeInterval(16 * 3600))
        XCTAssertEqual(floor(actual.created.timeIntervalSince1970), floor(s.created.addingTimeInterval(16 * 3600).timeIntervalSince1970))
        XCTAssertFalse(try e.execute([plan])[0].success, "A stale plan must never double-apply the shift")
    }

}
