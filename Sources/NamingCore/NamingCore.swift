import Foundation
import Darwin

public struct NamingError: LocalizedError {
    public let errorDescription: String?
    public init(_ message: String) { errorDescription = message }
}

public struct Fields: Codable, Equatable {
    public var year: String, month: String, day: String, primary: String, secondary: String, note: String
    public init(_ year: String = "", _ month: String = "", _ day: String = "", _ primary: String = "", _ secondary: String = "", _ note: String = "") {
        self.year = year; self.month = month; self.day = day; self.primary = primary; self.secondary = secondary; self.note = note
    }
    public var values: [String] { [year, month, day, primary, secondary, note] }
    public mutating func set(_ index: Int, _ value: String) {
        switch index { case 0: year = value; case 1: month = value; case 2: day = value; case 3: primary = value; case 4: secondary = value; case 5: note = value; default: break }
    }
    private var trimmed: [String] { values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
    public var errors: [String] {
        let v = trimmed
        var result: [String] = []
        let asciiDigits = CharacterSet(charactersIn: "0123456789")
        let numeric = v.prefix(3).allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy { asciiDigits.contains($0) } }
        if !numeric || v[0].count != 4 || v[1].count > 2 || v[2].count > 2 {
            result.append("请填写四位年、月、日")
        } else if let y = Int(v[0]), let m = Int(v[1]), let d = Int(v[2]) {
            let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
            let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            if !(1...9999).contains(y) || !(1...12).contains(m) || d < 1 || ((1...12).contains(m) && d > days[m - 1]) {
                result.append("日期不存在，请检查年月日")
            }
        }
        if v[3].isEmpty { result.append("一级标题不能为空") }
        let forbidden = CharacterSet(charactersIn: "_/\\:").union(.controlCharacters)
        for (i, value) in values.enumerated() where i >= 3 {
            // An explicit closure avoids a Swift 6.4 optimized bound-method
            // miscompile here; verify this validator in release as well as debug.
            if value.unicodeScalars.contains(where: { forbidden.contains($0) }) {
                result.append("\(["一级标题", "二级标题", "备注"][i - 3])不能含路径字符、控制字符或下划线")
            }
        }
        return result
    }
    public func name(extension ext: String = "") throws -> String {
        guard errors.isEmpty else { throw NamingError(errors.joined(separator: "；")) }
        let v = trimmed
        var parts = [String(format: "%04d-%02d-%02d", Int(v[0])!, Int(v[1])!, Int(v[2])!), v[3], v[4], v[5]]
        while parts.last == "" { parts.removeLast() }
        let name = parts.joined(separator: "_") + (ext.isEmpty ? "" : "." + ext)
        guard !ext.contains("/"), !ext.contains("\0"), name.utf8.count <= 255 else { throw NamingError("目标名称过长或扩展名无效") }
        return name
    }
}

public struct Parsed {
    public var fields: Fields
    public var compliant: Bool
    public var message: String
}

public enum Naming {
    public static func display(_ value: String) -> String { value.replacingOccurrences(of: "_", with: " ") }
    public static func parse(_ name: String, isDirectory: Bool) -> Parsed {
        let ext = isDirectory ? "" : (name as NSString).pathExtension
        let stem = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        let regex = try! NSRegularExpression(pattern: #"^(\d{4})[-_.年](\d{1,2})[-_.月](\d{1,2})日?(?:[_ .-]+(.*))?$"#)
        var fields = Fields()
        if let match = regex.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)) {
            func capture(_ i: Int) -> String { guard let range = Range(match.range(at: i), in: stem) else { return "" }; return String(stem[range]) }
            fields.year = capture(1); fields.month = capture(2); fields.day = capture(3)
            let rest = capture(4)
            let parts = rest.components(separatedBy: "_")
            if parts.count <= 3 {
                fields.primary = parts[0]
                if parts.count > 1 { fields.secondary = parts[1] }
                if parts.count > 2 { fields.note = parts[2] }
            }
        }
        let canonical = try? fields.name(extension: ext)
        let compliant = canonical == name
        let message: String
        if compliant { message = "六字段已解析；可选字段可为空" }
        else if !fields.errors.isEmpty { message = fields.errors.joined(separator: "；") }
        else { message = "已提取候选值，请核对标题与日期后预览" }
        return Parsed(fields: fields, compliant: compliant, message: message)
    }
}

public struct Identity: Codable, Equatable {
    public let inode: UInt64
    public let device: Int32
    public let birthSeconds: Int64
    public let birthNanoseconds: Int64
    init(_ info: stat) {
        inode = UInt64(info.st_ino); device = info.st_dev
        birthSeconds = Int64(info.st_birthtimespec.tv_sec); birthNanoseconds = Int64(info.st_birthtimespec.tv_nsec)
    }
}

private func infoAt(_ url: URL) throws -> stat {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw NamingError("无法读取：\(Naming.display(url.path))（\(String(cString: strerror(errno)))）") }
    return value
}
private func exists(_ url: URL) -> Bool { var value = stat(); return lstat(url.path, &value) == 0 }
private func identityAt(_ url: URL) -> Identity? { (try? infoAt(url)).map(Identity.init) }

public struct Item: Identifiable {
    public var id: String { url.path }
    public var url: URL
    public var identity: Identity
    public var parentIdentity: Identity
    public var directory: Bool
    public var parsed: Parsed
    public var ext: String
}
public struct ScanOptions {
    public var folders: Bool
    public var files: Bool
    public init(folders: Bool = false, files: Bool = false) { self.folders = folders; self.files = files }
}
public struct ScanResult { public var items: [Item] = []; public var skipped: [String] = [] }
public enum Scanner {
    public static func scan(_ urls: [URL], options: ScanOptions = ScanOptions()) -> ScanResult {
        var result = ScanResult()
        var seen = Set<String>()
        let explicitPaths = Set(urls.map { $0.standardizedFileURL.path })
        var stack = urls.reversed().map { ($0.standardizedFileURL, true) }
        while let (url, explicit) = stack.popLast() {
            guard seen.insert(url.path).inserted else { continue }
            do {
                let info = try infoAt(url)
                let type = info.st_mode & S_IFMT
                guard type == S_IFDIR || type == S_IFREG else { throw NamingError("跳过符号链接或特殊文件") }
                let directory = type == S_IFDIR
                let resource = try url.resourceValues(forKeys: [.isPackageKey, .isHiddenKey])
                guard resource.isPackage != true else { throw NamingError("跳过应用包或文件包") }
                guard resource.isHidden != true else { throw NamingError("跳过隐藏项目") }
                if explicit || explicitPaths.contains(url.path) || (directory ? options.folders : options.files) {
                    let parentInfo = try infoAt(url.deletingLastPathComponent())
                    // A leaf reached through a symlink parent is not a stable rename target.
                    guard parentInfo.st_mode & S_IFMT == S_IFDIR else { throw NamingError("父目录不是普通目录") }
                    result.items.append(Item(url: url, identity: Identity(info), parentIdentity: Identity(parentInfo), directory: directory,
                                             parsed: Naming.parse(url.lastPathComponent, isDirectory: directory), ext: directory ? "" : url.pathExtension))
                }
                if directory && (options.folders || options.files) {
                    // Foundation can return /private/var children for a /var parent.
                    // Keep children in the same path namespace for identity and ancestor mappings.
                    let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                        .map { url.appendingPathComponent($0.lastPathComponent).standardizedFileURL }.sorted { $0.path < $1.path }
                    stack.append(contentsOf: children.reversed().map { ($0, false) })
                }
            } catch { result.skipped.append("\(Naming.display(url.path))：\(error.localizedDescription)") }
        }
        result.items.sort { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        return result
    }
}

public struct Change {
    public let item: Item
    public let target: URL
}
public struct Batch: Codable {
    public var id = UUID()
    public var date = Date()
    public var records: [Record] = []
    public var completed: Int { records.filter { $0.state == "done" }.count }
    public var errors: [String] { records.compactMap { $0.error } }
}
public struct Record: Codable {
    public var source: String
    public var target: String
    public var identity: Identity
    public var parentIdentity: Identity
    public var state: String
    public var error: String?
}

/// Serial use only. Each batch is a durable sequence, not an atomic transaction.
public final class RenameEngine {
    public let journalDirectory: URL
    public init(journalDirectory: URL) throws {
        self.journalDirectory = journalDirectory
        try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public func preview(_ drafts: [(Item, Fields)]) throws -> [Change] {
        var sources = Set<String>()
        let changes = try drafts.compactMap { item, fields -> Change? in
            guard sources.insert(item.id).inserted else { return nil }
            let name = try fields.name(extension: item.ext)
            if name == item.url.lastPathComponent { return nil }
            return Change(item: item, target: item.url.deletingLastPathComponent().appendingPathComponent(name))
        }.sorted {
            let a = $0.item.url.pathComponents.count, b = $1.item.url.pathComponents.count
            return a == b ? $0.item.url.path < $1.item.url.path : a > b
        }
        try validate(changes)
        return changes
    }
    private func validate(_ changes: [Change]) throws {
        var targets = Set<String>()
        for change in changes {
            let source = change.item.url
            let parent = source.deletingLastPathComponent()
            guard identityAt(source) == change.item.identity, identityAt(parent) == change.item.parentIdentity else {
                throw NamingError("文件或父目录已移动或被替换，请重新导入：\(Naming.display(source.path))")
            }
            guard !exists(change.target) else { throw NamingError("目标名称已存在：\(Naming.display(change.target.path))") }
            guard access(parent.path, W_OK | X_OK) == 0 else { throw NamingError("没有改名权限：\(Naming.display(parent.path))") }
            let sensitive = (try? parent.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames ?? false
            let name = change.target.lastPathComponent.precomposedStringWithCanonicalMapping
            let key = parent.path + "/" + (sensitive ? name : name.lowercased())
            guard targets.insert(key).inserted else { throw NamingError("所选项目产生同名目标：\(Naming.display(change.target.path))") }
            let maximum = pathconf(parent.path, _PC_NAME_MAX)
            guard change.target.lastPathComponent.utf8.count <= (maximum > 0 ? maximum : 255) else { throw NamingError("目标名称超出磁盘长度限制") }
        }
    }
    public func execute(_ changes: [Change]) throws -> Batch {
        try validate(changes)
        var batch = Batch()
        batch.records = changes.map { Record(source: $0.item.url.path, target: $0.target.path, identity: $0.item.identity, parentIdentity: $0.item.parentIdentity, state: "planned") }
        guard !changes.isEmpty else { return batch }
        try save(batch)
        for i in batch.records.indices {
            batch.records[i].state = "pending"
            try save(batch) // Intent must be durable before touching a user's file.
            do {
                let record = batch.records[i]
                try move(record.source, record.target, identity: record.identity, parentIdentity: record.parentIdentity)
                batch.records[i].state = "done"
            } catch {
                batch.records[i].state = "failed"
                batch.records[i].error = "\(Naming.display(batch.records[i].source))：\(error.localizedDescription)"
            }
            try save(batch)
        }
        return batch
    }
    private func move(_ from: String, _ to: String, identity: Identity, parentIdentity: Identity) throws {
        let source = URL(fileURLWithPath: from), target = URL(fileURLWithPath: to)
        let parent = source.deletingLastPathComponent()
        guard target.deletingLastPathComponent() == parent else { throw NamingError("仅支持同目录改名") }
        let fd = open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw NamingError("无法打开父目录：\(String(cString: strerror(errno)))") }
        defer { close(fd) }
        var directory = stat(), current = stat()
        guard fstat(fd, &directory) == 0, Identity(directory) == parentIdentity,
              fstatat(fd, source.lastPathComponent, &current, AT_SYMLINK_NOFOLLOW) == 0,
              Identity(current) == identity, current.st_mode & S_IFMT != S_IFLNK else {
            throw NamingError("原项目或父目录已改变，请重新检查")
        }
        guard renameatx_np(fd, source.lastPathComponent, fd, target.lastPathComponent, UInt32(RENAME_EXCL)) == 0 else {
            throw NamingError("改名失败，未覆盖目标：\(String(cString: strerror(errno)))")
        }
    }
    private func fileFor(_ batch: Batch) -> URL { journalDirectory.appendingPathComponent(batch.id.uuidString + ".json") }
    private func save(_ batch: Batch) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = fileFor(batch)
        do {
            try encoder.encode(batch).write(to: url, options: [.atomic])
            _ = chmod(url.path, 0o600)
            let fd = open(url.path, O_RDONLY)
            guard fd >= 0 else { throw NamingError("无法打开日志") }
            defer { close(fd) }
            guard fsync(fd) == 0 else { throw NamingError("无法同步日志到磁盘") }
        } catch { throw NamingError("无法保存操作记录；请停止改名并检查历史记录：\(error.localizedDescription)") }
    }
    private func recover(_ input: Batch) throws -> Batch {
        var batch = input
        var changed = false
        for i in batch.records.indices {
            let r = batch.records[i]
            guard r.state == "pending" || r.state == "undoPending" else { continue }
            let atSource = identityAt(URL(fileURLWithPath: r.source)) == r.identity
            let atTarget = identityAt(URL(fileURLWithPath: r.target)) == r.identity
            guard atSource != atTarget else { throw NamingError("日志存在无法自动确认的中断操作，请检查：\(Naming.display(r.source))") }
            if r.state == "pending" { batch.records[i].state = atTarget ? "done" : "failed" }
            else { batch.records[i].state = atSource ? "undone" : "done" }
            batch.records[i].error = nil
            changed = true
        }
        if changed { try save(batch) }
        return batch
    }
    public func latestUndoable() throws -> Batch? {
        let urls = try FileManager.default.contentsOfDirectory(at: journalDirectory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        var batches: [Batch] = []
        for url in urls { batches.append(try recover(JSONDecoder().decode(Batch.self, from: Data(contentsOf: url)))) }
        return batches.filter { $0.completed > 0 }.sorted { $0.date > $1.date }.first
    }
    public func undo(_ input: Batch) throws -> Batch {
        // Re-read the durable state, so a stale preview cannot undo twice.
        var batch = try recover(JSONDecoder().decode(Batch.self, from: Data(contentsOf: fileFor(input))))
        for i in batch.records.indices.reversed() where batch.records[i].state == "done" {
            batch.records[i].state = "undoPending"; batch.records[i].error = nil
            try save(batch)
            let r = batch.records[i]
            do {
                try move(r.target, r.source, identity: r.identity, parentIdentity: r.parentIdentity)
                batch.records[i].state = "undone"
            } catch {
                batch.records[i].state = "done"
                batch.records[i].error = "撤销停止：\(Naming.display(r.target))：\(error.localizedDescription)"
                try save(batch)
                break // Do not continue to children when their parent failed to restore.
            }
            // A journal-write failure after a successful move must leave the durable
            // undoPending intent intact, rather than falsely reverting it to done.
            try save(batch)
        }
        return batch
    }
    /// Map every tracked path after successful operations, including unselected descendants.
    public static func relocated(_ url: URL, batch: Batch, undo: Bool = false) -> URL {
        var path = url.path
        let records = undo ? Array(batch.records.reversed()).filter { $0.state == "undone" } : batch.records.filter { $0.state == "done" }
        for r in records {
            let from = undo ? r.target : r.source, to = undo ? r.source : r.target
            if path == from { path = to }
            else if path.hasPrefix(from + "/") { path = to + path.dropFirst(from.count) }
        }
        return URL(fileURLWithPath: path)
    }
}
