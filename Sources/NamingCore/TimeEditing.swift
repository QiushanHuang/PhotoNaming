import Foundation
import Darwin

public enum TimeField: String, CaseIterable, Codable { case created, content, modified }
public enum TimeMode: Int { case set, shift, sync }
public struct TimeRequest {
    public var mode: TimeMode
    public var fields: Set<TimeField>
    public var target: Date
    public var delta: TimeInterval
    public var zone: TimeZone
    public init(mode: TimeMode, fields: Set<TimeField>, target: Date, delta: TimeInterval, zone: TimeZone) {
        self.mode = mode; self.fields = fields; self.target = target; self.delta = delta; self.zone = zone
    }
}
public struct TimeSnapshot: Codable {
    public var path: String
    public var inode: UInt64
    public var device: Int32
    public var size: Int64
    public var created: Date
    public var modified: Date
    public var content: Date?
}
public struct TimePlan: Codable {
    public var before: TimeSnapshot
    public var created: Date
    public var modified: Date
    public var content: Date?
    public var fields: Set<TimeField>
    public var zone: String
}
public enum TimeText {
    public static func parse(_ value: String, zone: TimeZone) throws -> Date {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.isLenient = false
        f.dateFormat = value.count > 19 ? "yyyy:MM:dd HH:mm:ssXXXXX" : "yyyy:MM:dd HH:mm:ss"
        guard let d = f.date(from: value) else { throw NamingError("无效时间：\(value)") }; return d
    }
    public static func string(_ value: Date?, zone: TimeZone) -> String {
        guard let value else { return "无拍摄时间" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy-MM-dd HH:mm:ss XXXXX"
        return f.string(from: value)
    }
}
public enum TimePlanner {
    public static func plan(_ s: TimeSnapshot, request r: TimeRequest) throws -> TimePlan {
        let fields = r.mode == .sync ? r.fields.subtracting([.content]) : r.fields
        guard !fields.isEmpty else { throw NamingError("请至少选择一种可修改的时间") }
        guard r.delta.isFinite, abs(r.delta) <= 315_576_000_000 else { throw NamingError("时间差超出允许范围") }
        func changed(_ field: TimeField, _ old: Date?) throws -> Date? {
            guard fields.contains(field) else { return old }
            switch r.mode {
            case .set: return r.target
            case .shift:
                guard let old else { throw NamingError("缺少内容拍摄时间，不能计算平移；请先使用统一时间补入") }
                return old.addingTimeInterval(r.delta)
            case .sync:
                guard let content = s.content else { throw NamingError("缺少内容拍摄时间，不能同步文件时间") }
                return content
            }
        }
        let p = try TimePlan(before: s, created: changed(.created, s.created)!, modified: changed(.modified, s.modified)!, content: changed(.content, s.content), fields: fields, zone: r.zone.identifier)
        for d in [p.created, p.modified] + (p.content.map { [$0] } ?? []) {
            guard d.timeIntervalSince1970.isFinite, d >= Date(timeIntervalSince1970: -2_208_988_800), d < Date(timeIntervalSince1970: 32_503_680_000) else { throw NamingError("目标时间须在1900至2999年之间") }
        }
        return p
    }
}

public struct TimeOutcome: Codable {
    public var plan: TimePlan
    public var success: Bool
    public var message: String
}

/// Serial worker only. Metadata edits are prepared on a same-directory temporary
/// copy. Every write is verified and independently reported; batches are not atomic.
public final class TimeEngine {
    private let journal: URL
    public init(journalDirectory: URL) throws {
        journal = journalDirectory
        try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public static let extensions: Set<String> = ["jpg", "jpeg", "heic", "heif", "tif", "tiff", "png", "arw", "dng", "cr2", "cr3", "nef", "rw2", "orf", "raf", "mp4", "mov", "m4v"]
    public static func collect(_ inputs: [URL]) -> [URL] {
        var found: [String: URL] = [:]
        func accept(_ u: URL) {
            guard let v = try? u.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey]), v.isRegularFile == true, v.isSymbolicLink != true, v.isHidden != true, extensions.contains(u.pathExtension.lowercased()) else { return }
            found[u.standardizedFileURL.path] = u.standardizedFileURL
        }
        for u in inputs {
            guard let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .isPackageKey]), v.isSymbolicLink != true, v.isHidden != true, v.isPackage != true else { continue }
            if v.isDirectory == true {
                guard let walk = FileManager.default.enumerator(at: u, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                for case let f as URL in walk {
                    if (try? f.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { continue }
                    accept(f)
                }
            } else { accept(u) }
        }
        return found.values.sorted { $0.path < $1.path }
    }
    private func statFile(_ url: URL) throws -> stat {
        var s = stat()
        guard lstat(url.path, &s) == 0, s.st_mode & S_IFMT == S_IFREG else { throw NamingError("文件不存在、不是普通文件或是符号链接：\(url.path)") }
        return s
    }
    private func date(_ ts: timespec) -> Date { Date(timeIntervalSince1970: Double(ts.tv_sec) + Double(ts.tv_nsec) / 1e9) }
    public static var toolURL: URL {
        if let root = Bundle.main.resourceURL {
            let u = root.appendingPathComponent("ExifTool/exiftool")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return Bundle.module.url(forResource: "exiftool", withExtension: nil, subdirectory: "ExifTool")!
    }
    private func run(_ args: [String]) throws -> Data {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoNamingTool-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("stdout"), err = dir.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: out.path, contents: nil); FileManager.default.createFile(atPath: err.path, contents: nil)
        let oh = try FileHandle(forWritingTo: out), eh = try FileHandle(forWritingTo: err)
        defer { try? oh.close(); try? eh.close() }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [Self.toolURL.path, "-config", "", "-charset", "filename=UTF8"] + args
        p.environment = ProcessInfo.processInfo.environment.merging(["TZ": "UTC"]) { _, new in new }
        p.standardOutput = oh; p.standardError = eh
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NamingError(String(decoding: try Data(contentsOf: err), as: UTF8.self) + String(decoding: try Data(contentsOf: out), as: UTF8.self))
        }
        return try Data(contentsOf: out)
    }
    public func read(_ url: URL, zone: TimeZone) throws -> TimeSnapshot {
        let s = try statFile(url)
        let data = try run(["-j", "-api", "QuickTimeUTC=1", "-DateTimeOriginal", "-OffsetTimeOriginal", "-CreateDate", "-CreationDate", "-FileType", url.path])
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let row = rows.first else { throw NamingError("无法读取元数据：\(url.path)") }
        if let error = row["Error"] as? String { throw NamingError(error) }
        var content: Date?
        if let raw = (row["DateTimeOriginal"] ?? row["CreationDate"] ?? row["CreateDate"]) as? String {
            var text = String(raw.prefix(19))
            let suffix = String(raw.dropFirst(19))
            if suffix.hasPrefix("+") || suffix.hasPrefix("-") || suffix == "Z" { text += suffix }
            else if let offset = row["OffsetTimeOriginal"] as? String, text.count == 19 { text += offset }
            let movie = ["MOV", "MP4", "M4V"].contains(row["FileType"] as? String ?? "")
            content = try? TimeText.parse(text, zone: movie && row["DateTimeOriginal"] == nil ? TimeZone(secondsFromGMT: 0)! : zone)
        }
        let after = try statFile(url)
        guard s.st_ino == after.st_ino, s.st_size == after.st_size, s.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, s.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { throw NamingError("读取期间文件发生变化，请重新导入") }
        return TimeSnapshot(path: url.path, inode: UInt64(s.st_ino), device: s.st_dev, size: s.st_size, created: date(s.st_birthtimespec), modified: date(s.st_mtimespec), content: content)
    }
    private func matches(_ url: URL, _ before: TimeSnapshot) throws -> Bool {
        let s = try statFile(url)
        return UInt64(s.st_ino) == before.inode && s.st_dev == before.device && s.st_size == before.size && abs(date(s.st_birthtimespec).timeIntervalSince(before.created)) < 0.00001 && abs(date(s.st_mtimespec).timeIntervalSince(before.modified)) < 0.00001
    }
    private func exchange(_ a: URL, _ b: URL) throws {
        var coordinationError: NSError?
        var operationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: b, options: .forReplacing, error: &coordinationError) { actual in
            do { try self.exchangeFiles(a, actual) } catch { operationError = error }
        }
        if let error = operationError ?? coordinationError { throw error }
    }
    private func exchangeFiles(_ a: URL, _ b: URL) throws {
        if renameatx_np(AT_FDCWD, a.path, AT_FDCWD, b.path, UInt32(RENAME_SWAP)) == 0 { return }
        let reason = errno
        guard reason == ENOTSUP || reason == EINVAL || reason == ENOSYS else { throw NamingError("无法替换文件：\(String(cString: strerror(reason)))") }
        // exFAT does not implement RENAME_SWAP or RENAME_EXCL. Coordinate a
        // recoverable three-move exchange, never delete the displaced original.
        let saved = URL(fileURLWithPath: a.path + ".displaced")
        let fm = FileManager.default
        try fm.moveItem(at: b, to: saved)
        do { try fm.moveItem(at: a, to: b) }
        catch {
            do { try fm.moveItem(at: saved, to: b) }
            catch { throw NamingError("替换中断；原文件保留于：\(saved.path)。请勿删除该文件。") }
            throw error
        }
        do { try fm.moveItem(at: saved, to: a) }
        catch { throw NamingError("替换中断；原文件保留于：\(saved.path)，新文件位于：\(b.path)") }
    }
    private func apply(_ plan: TimePlan, stage: (String) throws -> Void) throws {
        let url = URL(fileURLWithPath: plan.before.path), zone = TimeZone(identifier: plan.zone) ?? .current
        guard try matches(url, plan.before) else { throw NamingError("文件自预览后发生变化，请重新预览") }
        if plan.fields.contains(.content), let content = plan.content {
            let temp = url.deletingLastPathComponent().appendingPathComponent(".photonaming-" + UUID().uuidString + "." + url.pathExtension)
            var keepTemp = false
            defer { if !keepTemp { try? FileManager.default.removeItem(at: temp) } }
            try stage("执行中；临时副本：\(temp.path)；若中断，移出的原文件可能位于：\(temp.path).displaced")
            try FileManager.default.copyItem(at: url, to: temp)
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = zone; f.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
            let text = f.string(from: content)
            f.dateFormat = "XXXXX"; let offset = f.string(from: content).replacingOccurrences(of: "Z", with: "+00:00")
            let movie = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
            var args = ["-overwrite_original", "-api", "QuickTimeUTC=1", "-AllDates=\(text)"]
            if movie {
                args += ["-TrackCreateDate=\(text)", "-TrackModifyDate=\(text)", "-MediaCreateDate=\(text)", "-MediaModifyDate=\(text)", "-Keys:CreationDate=\(text)"]
            } else {
                args += ["-OffsetTime=\(offset)", "-OffsetTimeOriginal=\(offset)", "-OffsetTimeDigitized=\(offset)", "-SubSecTime=", "-SubSecTimeOriginal=", "-SubSecTimeDigitized="]
            }
            _ = try run(args + [temp.path])
            guard let actual = try read(temp, zone: zone).content, abs(actual.timeIntervalSince(content)) < 1 else { throw NamingError("临时文件的内容时间写入核验失败；原文件未替换") }
            guard try matches(url, plan.before) else { throw NamingError("文件自预览后发生变化，取消替换") }
            do { try exchange(temp, url); keepTemp = true }
            catch { keepTemp = true; throw error }
            guard try matches(temp, plan.before) else {
                do { try exchange(temp, url) }
                catch { keepTemp = true; throw NamingError("替换时文件发生变化，回退失败；请检查：\(temp.path)；\(error.localizedDescription)") }
                keepTemp = false
                throw NamingError("替换时文件发生变化，已恢复")
            }
            do {
                try setFileDates(url, created: plan.created, modified: plan.modified)
                let verified = try read(url, zone: zone)
                try verify(verified, plan)
                keepTemp = false
            } catch {
                let originalError = error
                do { try exchange(temp, url) }
                catch { keepTemp = true; throw NamingError("核验失败且回退失败：\(originalError.localizedDescription)；\(error.localizedDescription)；检查：\(temp.path)") }
                keepTemp = false
                throw originalError
            }
        } else {
            do {
                try setFileDates(url, created: plan.created, modified: plan.modified)
                try verify(read(url, zone: zone), plan)
            } catch {
                do { try setFileDates(url, created: plan.before.created, modified: plan.before.modified) }
                catch { throw NamingError("写入失败且恢复原文件时间失败：\(error.localizedDescription)") }
                throw error
            }
        }
    }
    private func setFileDates(_ url: URL, created: Date, modified: Date) throws {
        // Creation must be set after modification: some filesystems clamp it to mtime.
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        var attributes = attrlist()
        attributes.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        attributes.commonattr = attrgroup_t(ATTR_CMN_CRTIME)
        let seconds = floor(created.timeIntervalSince1970)
        var stamp = timespec(tv_sec: Int(seconds), tv_nsec: Int((created.timeIntervalSince1970 - seconds) * 1e9))
        guard setattrlist(url.path, &attributes, &stamp, MemoryLayout<timespec>.size, 0) == 0 else { throw NamingError("无法设置文件创建时间：\(String(cString: strerror(errno)))") }
    }
    private func isExFAT(_ path: String) -> Bool {
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return false }
        let name = withUnsafePointer(to: &fs.f_fstypename) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) { String(cString: $0) }
        }
        return name.lowercased() == "exfat"
    }
    private func verify(_ actual: TimeSnapshot, _ p: TimePlan) throws {
        // Apple's exFAT driver exposes subsecond birth times on creation, but
        // truncates them on setattrlist writes. Compare full seconds only there.
        let birthMatches = isExFAT(actual.path)
            ? floor(actual.created.timeIntervalSince1970) == floor(p.created.timeIntervalSince1970)
            : abs(actual.created.timeIntervalSince(p.created)) < 0.01
        guard birthMatches, abs(actual.modified.timeIntervalSince(p.modified)) < 0.01 else { throw NamingError("文件创建/修改时间核验失败（创建偏差：\(actual.created.timeIntervalSince(p.created)) 秒；修改偏差：\(actual.modified.timeIntervalSince(p.modified)) 秒）") }
        if p.fields.contains(.content) {
            guard let content = actual.content, let expected = p.content, abs(content.timeIntervalSince(expected)) < 1 else { throw NamingError("内容时间核验失败") }
        }
    }
    public func execute(_ plans: [TimePlan], progress: ((Int, Int) -> Void)? = nil) throws -> [TimeOutcome] {
        let log = journal.appendingPathComponent(UUID().uuidString + ".json")
        // Preserve a write-ahead plan. Never start if its durable record fails.
        var results = plans.map { TimeOutcome(plan: $0, success: false, message: "待执行") }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: log, options: .atomic)
        for i in plans.indices {
            do {
                try apply(plans[i]) { message in
                    results[i].message = message
                    try encoder.encode(results).write(to: log, options: .atomic)
                }
                results[i].success = true
                results[i].message = isExFAT(plans[i].before.path) ? "已写入并核验（exFAT文件创建时间按秒保存）" : "已写入并核验"
            }
            catch { results[i].message = error.localizedDescription }
            try encoder.encode(results).write(to: log, options: .atomic)
            progress?(i + 1, plans.count)
        }
        return results
    }
}
