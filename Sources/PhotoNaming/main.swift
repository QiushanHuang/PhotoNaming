import AppKit
import NamingCore

private let fieldTitles = ["年", "月", "日", "一级标题", "二级标题", "备注"]
private let blueSurface = NSColor(name: "ParsingSurface") { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(srgbRed: 0.13, green: 0.19, blue: 0.27, alpha: 1) : NSColor(srgbRed: 0.95, green: 0.975, blue: 1, alpha: 1) }

private func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let view = NSTextField(labelWithString: text)
    view.font = .systemFont(ofSize: size, weight: weight)
    view.textColor = color
    view.lineBreakMode = .byTruncatingTail
    return view
}
private func spacer() -> NSView { let view = NSView(); view.setContentHuggingPriority(.defaultLow, for: .horizontal); return view }
private func row(_ views: [NSView], spacing: CGFloat = 10) -> NSStackView {
    let view = NSStackView(views: views); view.orientation = .horizontal; view.spacing = spacing; view.alignment = .centerY; return view
}
private func urlsFrom(_ pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
}

final class DropZone: NSView {
    var onDrop: (([URL]) -> Void)?
    var enabled = true
    private var hovering = false
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        (hovering ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        path.fill(); (hovering ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.setLineDash([5, 4], count: 2, phase: 0); path.stroke()
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard enabled, !urlsFrom(sender.draggingPasteboard).isEmpty else { return [] }
        hovering = true; needsDisplay = true; return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { hovering = false; needsDisplay = true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        hovering = false; needsDisplay = true
        guard enabled else { return false }
        let urls = urlsFrom(sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }; onDrop?(urls); return true
    }
}

final class GroupHeader: NSTableHeaderView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let tableView else { return }
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        for i in 0..<tableView.numberOfColumns {
            let rect = headerRect(ofColumn: i)
            let bottom = NSRect(x: rect.minX, y: 31, width: rect.width, height: 30)
            (i < 2 ? NSColor.controlBackgroundColor : blueSurface).setFill(); bottom.fill()
            let title = tableView.tableColumns[i].title
            (title as NSString).draw(at: NSPoint(x: rect.minX + 10, y: 38), withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        }
        if tableView.numberOfColumns >= 8 {
            let split = headerRect(ofColumn: 2).minX
            NSColor.controlBackgroundColor.setFill(); NSRect(x: 0, y: 0, width: split, height: 31).fill()
            blueSurface.setFill(); NSRect(x: split, y: 0, width: bounds.width - split, height: 31).fill()
            ("原文件状态" as NSString).draw(at: NSPoint(x: 12, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor])
            ("解析状态" as NSString).draw(at: NSPoint(x: split + 12, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.controlAccentColor])
        }
        NSColor.separatorColor.setFill(); NSRect(x: 0, y: 61, width: bounds.width, height: 1).fill()
    }
}
final class EditField: NSTextField {
    var itemID = ""
    var fieldIndex = 0
}

final class AppController: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private let table = NSTableView()
    private let filter = NSSegmentedControl(labels: ["全部 · 0", "已符合 · 0", "未符合 · 0"], trackingMode: .selectOne, target: nil, action: nil)
    private let drop = DropZone()
    private let folders = NSButton(checkboxWithTitle: "包含子文件夹", target: nil, action: nil)
    private let files = NSButton(checkboxWithTitle: "包含内部文件", target: nil, action: nil)
    private let status = label("拖入文件或文件夹开始检查", size: 13)
    private let detail = label("", size: 12, color: .secondaryLabelColor)
    private let count = label("", size: 12, color: .secondaryLabelColor)
    private let empty = label("还没有导入项目\n拖入上方区域，或点击“选择文件或文件夹”", size: 15, color: .secondaryLabelColor)
    private var importButton: NSButton!, batchButton: NSButton!, previewButton: NSButton!, removeButton: NSButton!, undoButton: NSButton!, selectButton: NSButton!, reportButton: NSButton!
    private var items: [Item] = []
    private var drafts: [String: Fields] = [:]
    private var visible: [Item] = []
    private var busy = false
    private var report = ""
    private var engine: RenameEngine!
    private let worker = DispatchQueue(label: "studio.qiushan.PhotoNaming.files", qos: .userInitiated)
    private var startupURLs: [URL] = []
    private var panelOpen = false
    private var lastUndo: Batch?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: iconURL)
        }
        configureMenu()
        buildWindow()
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            engine = try RenameEngine(journalDirectory: support.appendingPathComponent("PhotoNaming/History"))
            lastUndo = try engine.latestUndoable()
        } catch { showError("操作记录不可用", error.localizedDescription) }
        reload()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let index = CommandLine.arguments.firstIndex(of: "--import") {
            startupURLs += CommandLine.arguments.dropFirst(index + 1).map { URL(fileURLWithPath: $0) }
        }
        if !startupURLs.isEmpty { let urls = startupURLs; startupURLs = []; importURLs(urls) }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        if window == nil { startupURLs += urls } else { importURLs(urls) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { NSSound.beep(); return .terminateCancel }; return .terminateNow
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { if busy { NSSound.beep(); return false }; return true }
    private func configureMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于照片命名", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出照片命名", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; main.addItem(appItem)
        let editItem = NSMenuItem(); editItem.title = "编辑"; let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销文本编辑", Selector(("undo:")), "z"), ("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.submenu = editMenu; main.addItem(editItem)
        NSApp.mainMenu = main
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b
    }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1380, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "照片命名"; window.subtitle = "先检查，再整理，确认后同步"; window.minSize = NSSize(width: 1040, height: 700)
        window.center(); window.delegate = self; window.tabbingMode = .disallowed
        let body = NSStackView(); body.orientation = .vertical; body.alignment = .leading; body.spacing = 16
        body.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 18, right: 24)
        window.contentView = body
        let brand = NSImageView()
        if let logoURL = Bundle.main.url(forResource: "BrandLogo", withExtension: "png") { brand.image = NSImage(contentsOf: logoURL) }
        brand.widthAnchor.constraint(equalToConstant: 44).isActive = true
        brand.heightAnchor.constraint(equalToConstant: 44).isActive = true
        brand.setAccessibilityLabel("PhotoNaming Logo")
        let heading = row([brand, label("照片命名", size: 24, weight: .semibold), spacer(), label("本地文件 · 确认后改名", size: 12, color: .secondaryLabelColor)])
        add(heading, to: body)
        add(label("日期排列清楚，主题一眼可读。分隔符由应用自动处理。", size: 13, color: .secondaryLabelColor), to: body)
        importButton = button("选择文件或文件夹…", #selector(chooseFiles))
        let dropLabels = NSStackView(views: [label("将文件或文件夹拖到这里", size: 17, weight: .medium), label("支持多项导入；同一项目重复拖入只显示一次", size: 12, color: .secondaryLabelColor)])
        dropLabels.orientation = .vertical; dropLabels.alignment = .leading; dropLabels.spacing = 7
        let icon = NSImageView(image: NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)!)
        icon.contentTintColor = .controlAccentColor; icon.widthAnchor.constraint(equalToConstant: 32).isActive = true; icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let dropContent = row([icon, dropLabels, spacer(), importButton], spacing: 18)
        drop.addSubview(dropContent); dropContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([dropContent.leadingAnchor.constraint(equalTo: drop.leadingAnchor, constant: 24), dropContent.trailingAnchor.constraint(equalTo: drop.trailingAnchor, constant: -24), dropContent.centerYAnchor.constraint(equalTo: drop.centerYAnchor)])
        drop.heightAnchor.constraint(equalToConstant: 96).isActive = true
        drop.onDrop = { [weak self] urls in self?.importURLs(urls) }; add(drop, to: body)
        add(row([folders, files, spacer(), label("默认只检查拖入项本身 · 选项用于后续导入", size: 12, color: .secondaryLabelColor)]), to: body)
        filter.selectedSegment = 0; filter.target = self; filter.action = #selector(filterChanged)
        for i in 0..<3 { filter.setWidth(106, forSegment: i) }
        selectButton = button("选择可改名项", #selector(selectReady))
        batchButton = button("批量赋值…", #selector(batchEdit))
        removeButton = button("移出列表", #selector(removeSelected))
        add(row([filter, spacer(), selectButton, batchButton, removeButton], spacing: 8), to: body)
        table.dataSource = self; table.delegate = self; table.rowHeight = 62; table.intercellSpacing = .zero
        table.usesAlternatingRowBackgroundColors = false; table.allowsMultipleSelection = true; table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle; table.allowsColumnReordering = false
        table.style = .plain; table.gridStyleMask = [.solidHorizontalGridLineMask]; table.gridColor = .separatorColor
        let names = ["是否按要求", "原文件(夹)名"] + fieldTitles
        let widths: [CGFloat] = [106, 290, 74, 60, 60, 180, 170, 170]
        for i in names.indices {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(i)")); column.title = names[i]; column.width = widths[i]; column.minWidth = widths[i]
            column.resizingMask = i == 7 ? [.autoresizingMask, .userResizingMask] : .userResizingMask
            table.addTableColumn(column)
        }
        table.headerView = GroupHeader(frame: NSRect(x: 0, y: 0, width: 1310, height: 62))
        table.registerForDraggedTypes([.fileURL])
        let menu = NSMenu(); menu.addItem(withTitle: "在 Finder 中显示", action: #selector(revealSelected), keyEquivalent: "").target = self; table.menu = menu
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true; scroll.autohidesScrollers = true; scroll.borderType = .lineBorder
        let tableArea = NSView(); tableArea.addSubview(scroll); scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: tableArea.topAnchor), scroll.bottomAnchor.constraint(equalTo: tableArea.bottomAnchor), scroll.leadingAnchor.constraint(equalTo: tableArea.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: tableArea.trailingAnchor)])
        tableArea.addSubview(empty); empty.translatesAutoresizingMaskIntoConstraints = false; empty.alignment = .center; empty.maximumNumberOfLines = 3
        NSLayoutConstraint.activate([empty.centerXAnchor.constraint(equalTo: tableArea.centerXAnchor), empty.centerYAnchor.constraint(equalTo: tableArea.centerYAnchor)])
        tableArea.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        add(tableArea, to: body); tableArea.setContentHuggingPriority(.defaultLow, for: .vertical)
        add(row([count, spacer(), label("⌘ / ⇧ 多选 · 双击字段编辑 · Tab 切换", size: 12, color: .secondaryLabelColor)]), to: body)
        add(label("年、月、日和一级标题必填；二级标题、备注可空。日期未知时请保留待填写。", size: 12, color: .secondaryLabelColor), to: body)
        detail.maximumNumberOfLines = 2; detail.lineBreakMode = .byTruncatingTail
        add(detail, to: body)
        previewButton = button("预览重命名…", #selector(preview)); previewButton.bezelColor = .controlAccentColor; previewButton.keyEquivalent = ""
        undoButton = button("撤销上次改名…", #selector(undoLast))
        reportButton = button("查看结果…", #selector(showReport))
        add(row([status, spacer(), reportButton, undoButton, previewButton]), to: body)
    }
    private func add(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view); view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
    }
    private var selected: [Item] { table.selectedRowIndexes.compactMap { visible.indices.contains($0) ? visible[$0] : nil } }
    private var selectedEditable: [Item] { selected.filter { !$0.parsed.compliant } }
    private func reload(select ids: Set<String> = []) {
        let segment = filter.selectedSegment
        visible = items.filter { segment == 0 || (segment == 1 ? $0.parsed.compliant : !$0.parsed.compliant) }
        table.reloadData()
        table.selectRowIndexes(IndexSet(visible.indices.filter { ids.contains(visible[$0].id) }), byExtendingSelection: false)
        for (i, text) in ["全部 · \(items.count)", "已符合 · \(items.filter { $0.parsed.compliant }.count)", "未符合 · \(items.filter { !$0.parsed.compliant }.count)"].enumerated() { filter.setLabel(text, forSegment: i) }
        empty.isHidden = !visible.isEmpty
        empty.stringValue = items.isEmpty ? "还没有导入项目\n拖入上方区域，或点击“选择文件或文件夹”" : "此筛选下没有项目"
        updateControls()
    }
    private func updateControls() {
        guard previewButton != nil else { return }
        let editing = selectedEditable
        count.stringValue = "显示 \(visible.count) 项 · 已选 \(selected.count) 项"
        previewButton.title = "预览重命名 · \(editing.count) 项"
        previewButton.isEnabled = !busy && engine != nil && !editing.isEmpty
        batchButton.isEnabled = !busy && !editing.isEmpty
        removeButton.isEnabled = !busy && !selected.isEmpty
        selectButton.isEnabled = !busy && visible.contains { !$0.parsed.compliant && (drafts[$0.id] ?? $0.parsed.fields).errors.isEmpty }
        undoButton.isEnabled = !busy && lastUndo != nil
        importButton.isEnabled = !busy; folders.isEnabled = !busy; files.isEnabled = !busy; filter.isEnabled = !busy; drop.enabled = !busy
        reportButton.isEnabled = !busy && !report.isEmpty
        if let item = selected.first {
            let values = drafts[item.id] ?? item.parsed.fields
            let errors = values.errors
            detail.stringValue = item.parsed.compliant ? "已符合：六字段已解析，空可选字段显示为 —。" : (errors.isEmpty ? "字段已填全，请核对候选值并预览。磁盘原名尚未改变。" : errors.joined(separator: "；"))
            detail.textColor = errors.isEmpty ? .secondaryLabelColor : .systemOrange
        } else { detail.stringValue = "选中要整理的行，在蓝色区域修改；也可以多选后统一赋值。"; detail.textColor = .secondaryLabelColor }
    }
    @objc private func chooseFiles() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = true; panel.prompt = "导入检查"
        panel.beginSheetModal(for: window) { [weak self] response in if response == .OK { self?.importURLs(panel.urls) } }
    }
    private func importURLs(_ urls: [URL]) {
        guard !busy, !panelOpen else { return }
        window.makeFirstResponder(nil)
        busy = true; status.stringValue = "正在读取名称…"; updateControls()
        let options = ScanOptions(folders: folders.state == .on, files: files.state == .on)
        worker.async { [weak self] in
            let result = Scanner.scan(urls, options: options)
            DispatchQueue.main.async { self?.finishImport(result) }
        }
    }
    private func finishImport(_ result: ScanResult) {
        var indexed = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var added = 0
        for item in result.items {
            if indexed[item.id] == nil { added += 1 }
            if indexed[item.id]?.identity != item.identity { drafts[item.id] = item.parsed.fields }
            indexed[item.id] = item
        }
        items = indexed.values.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        busy = false
        status.stringValue = "新增 \(added) 项 · 已跳过 \(result.skipped.count) 项"
        report = "导入完成：新增 \(added) 项。\n\n" + (result.skipped.isEmpty ? "无跳过项目。" : result.skipped.joined(separator: "\n"))
        reload()
    }
    @objc private func filterChanged() { window.makeFirstResponder(nil); reload() }
    @objc private func selectReady() {
        window.makeFirstResponder(nil)
        table.selectRowIndexes(IndexSet(visible.indices.filter { !visible[$0].parsed.compliant && (drafts[visible[$0].id] ?? visible[$0].parsed.fields).errors.isEmpty }), byExtendingSelection: false)
    }
    @objc private func removeSelected() {
        window.makeFirstResponder(nil)
        let ids = Set(selected.map(\.id)); items.removeAll { ids.contains($0.id) }; ids.forEach { drafts.removeValue(forKey: $0) }
        reload(); status.stringValue = "已从列表移出 \(ids.count) 项，文件未修改"
    }
    @objc private func revealSelected() {
        let candidates = table.clickedRow >= 0 && visible.indices.contains(table.clickedRow) ? [visible[table.clickedRow].url] : selected.map(\.url)
        NSWorkspace.shared.activateFileViewerSelecting(candidates)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { visible.count }
    func tableViewSelectionDidChange(_ notification: Notification) { updateControls() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row rowIndex: Int) -> NSView? {
        guard let tableColumn, let index = tableView.tableColumns.firstIndex(of: tableColumn), visible.indices.contains(rowIndex) else { return nil }
        let item = visible[rowIndex]
        let container = NSView()
        if index == 0 {
            let text = label(item.parsed.compliant ? "✓ 已符合" : "! 未符合", size: 12, weight: .medium, color: item.parsed.compliant ? .systemGreen : .systemOrange)
            container.addSubview(text); text.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12), text.centerYAnchor.constraint(equalTo: container.centerYAnchor)])
            container.setAccessibilityLabel(text.stringValue)
        } else if index == 1 {
            let name = label(Naming.display(item.url.lastPathComponent), size: 13, weight: .medium)
            let sub = label((item.directory ? "文件夹" : "文件") + " · " + Naming.display(item.url.deletingLastPathComponent().path), size: 11, color: .secondaryLabelColor)
            let content = NSStackView(views: [name, sub]); content.orientation = .vertical; content.alignment = .leading; content.spacing = 4
            container.addSubview(content); content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9), content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8), content.centerYAnchor.constraint(equalTo: container.centerYAnchor), name.widthAnchor.constraint(equalTo: content.widthAnchor), sub.widthAnchor.constraint(equalTo: content.widthAnchor)])
            container.toolTip = Naming.display(item.url.path) + "\n" + item.parsed.message
        } else {
            container.wantsLayer = true; container.layer?.backgroundColor = blueSurface.cgColor
            let field = EditField(); field.itemID = item.id; field.fieldIndex = index - 2
            let values = drafts[item.id] ?? item.parsed.fields
            field.stringValue = values.values[index - 2]
            field.font = index < 5 ? .monospacedDigitSystemFont(ofSize: 13, weight: .regular) : .systemFont(ofSize: 13)
            field.isEditable = !item.parsed.compliant && !busy; field.isSelectable = true; field.delegate = self
            field.isBordered = !item.parsed.compliant; field.isBezeled = !item.parsed.compliant; field.bezelStyle = .roundedBezel
            field.drawsBackground = !item.parsed.compliant
            field.backgroundColor = !item.parsed.compliant && index < 6 && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSColor.systemOrange.withAlphaComponent(0.10) : .textBackgroundColor
            field.placeholderString = item.parsed.compliant ? "—" : (index < 5 ? "待填" : (index == 5 ? "待填写" : "可空"))
            field.setAccessibilityLabel(fieldTitles[index - 2] + "，" + Naming.display(item.url.lastPathComponent))
            container.addSubview(field); field.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 7), field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -7), field.centerYAnchor.constraint(equalTo: container.centerYAnchor), field.heightAnchor.constraint(equalToConstant: 28)])
        }
        return container
    }
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? EditField, !busy else { return }
        var values = drafts[field.itemID] ?? Fields(); values.set(field.fieldIndex, field.stringValue); drafts[field.itemID] = values
        field.backgroundColor = field.fieldIndex < 4 && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSColor.systemOrange.withAlphaComponent(0.10) : .textBackgroundColor
        updateControls()
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard !busy, !panelOpen, !urlsFrom(info.draggingPasteboard).isEmpty else { return [] }
        tableView.setDropRow(-1, dropOperation: .above); return .copy
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard !busy, !panelOpen else { return false }; importURLs(urlsFrom(info.draggingPasteboard)); return true
    }
    @objc private func batchEdit() {
        window.makeFirstResponder(nil)
        let targets = selectedEditable
        guard !targets.isEmpty else { return }
        let alert = NSAlert(); alert.messageText = "为 \(targets.count) 项批量赋值"; alert.informativeText = "只替换勾选字段。勾选后留空会清空该字段；未勾选字段保留。"
        alert.addButton(withTitle: "应用到草稿"); alert.addButton(withTitle: "取消")
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 10; stack.alignment = .leading
        var toggles: [NSButton] = [], inputs: [NSTextField] = []
        for title in fieldTitles {
            let toggle = NSButton(checkboxWithTitle: title, target: nil, action: nil); toggle.widthAnchor.constraint(equalToConstant: 100).isActive = true
            let input = NSTextField(); input.placeholderString = "输入统一值"; input.widthAnchor.constraint(equalToConstant: 270).isActive = true
            stack.addArrangedSubview(row([toggle, input])); toggles.append(toggle); inputs.append(input)
        }
        stack.frame = NSRect(x: 0, y: 0, width: 390, height: 218); alert.accessoryView = stack
        panelOpen = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.panelOpen = false
            guard response == .alertFirstButtonReturn else { return }
            guard toggles.contains(where: { $0.state == .on }) else { return }
            for item in targets {
                var values = self.drafts[item.id] ?? item.parsed.fields
                for i in 0..<6 where toggles[i].state == .on { values.set(i, inputs[i].stringValue) }
                self.drafts[item.id] = values
            }
            self.reload(select: Set(targets.map(\.id))); self.status.stringValue = "已更新 \(targets.count) 项草稿，尚未改名"
        }
    }
    private func textAccessory(_ text: String, height: CGFloat = 320) -> NSScrollView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 680, height: height)); scroll.hasVerticalScroller = true; scroll.borderType = .lineBorder
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 660, height: height)); view.isEditable = false; view.isSelectable = true
        view.font = .systemFont(ofSize: 13); view.textContainerInset = NSSize(width: 12, height: 12); view.string = text
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false; view.autoresizingMask = [.width]
        view.textContainer?.containerSize = NSSize(width: 656, height: CGFloat.greatestFiniteMagnitude); view.textContainer?.widthTracksTextView = true
        scroll.documentView = view; return scroll
    }
    @objc private func preview() {
        window.makeFirstResponder(nil)
        guard !busy, let engine else { return }
        do {
            let targets = selectedEditable
            let invalid = targets.compactMap { item -> String? in
                let errors = (drafts[item.id] ?? item.parsed.fields).errors
                return errors.isEmpty ? nil : Naming.display(item.url.lastPathComponent) + "：" + errors.joined(separator: "；")
            }
            if !invalid.isEmpty { throw NamingError(invalid.joined(separator: "\n")) }
            let changes = try engine.preview(targets.map { ($0, drafts[$0.id] ?? $0.parsed.fields) })
            guard !changes.isEmpty else { return }
            let text = changes.enumerated().map { index, change in
                var final = change.target.path
                for other in changes where other.item.directory {
                    let from = other.item.url.path
                    if final.hasPrefix(from + "/") { final = other.target.path + final.dropFirst(from.count) }
                }
                return "\(index + 1). 原名：\(Naming.display(change.item.url.lastPathComponent))\n    新名：\(Naming.display(change.target.lastPathComponent))\n    原位置：\(Naming.display(change.item.url.deletingLastPathComponent().path))\n    最终位置：\(Naming.display(final))"
            }.joined(separator: "\n\n")
            let alert = NSAlert(); alert.messageText = "确认重命名 \(changes.count) 项？"
            alert.informativeText = "请核对日期与标题。真实名称使用下划线分隔，界面隐藏；扩展名保留。确认后立即改名，遇到冲突不会覆盖。"
            alert.accessoryView = textAccessory(text); alert.addButton(withTitle: "确认并重命名 \(changes.count) 项"); alert.addButton(withTitle: "返回编辑")
            panelOpen = true
            alert.beginSheetModal(for: window) { [weak self] response in
                guard let self else { return }; self.panelOpen = false
                if response == .alertFirstButtonReturn { self.execute(changes) }
            }
        } catch { showError("暂时无法重命名", error.localizedDescription) }
    }
    private func execute(_ changes: [Change]) {
        busy = true; status.stringValue = "正在改名并保存记录…"; updateControls(); table.reloadData()
        worker.async { [weak self] in
            guard let self else { return }
            do {
                let batch = try self.engine.execute(changes)
                DispatchQueue.main.async { self.refreshAfter(batch, undo: false) }
            } catch {
                DispatchQueue.main.async { self.busy = false; self.reload(); self.showError("改名未完成", error.localizedDescription); self.refreshHistory() }
            }
        }
    }
    private func refreshAfter(_ batch: Batch, undo: Bool) {
        let originalItems = items
        let urls = originalItems.map { RenameEngine.relocated($0.url, batch: batch, undo: undo) }
        worker.async { [weak self] in
            let scan = Scanner.scan(urls)
            DispatchQueue.main.async {
                guard let self else { return }
                self.items = scan.items
                var newDrafts: [String: Fields] = [:]
                for item in scan.items {
                    let old = originalItems.first { $0.identity == item.identity }
                    let unchanged = old?.url == item.url
                    newDrafts[item.id] = unchanged ? (self.drafts[item.id] ?? item.parsed.fields) : item.parsed.fields
                }
                self.drafts = newDrafts
                self.busy = false
                let done = undo ? batch.records.filter { $0.state == "undone" }.count : batch.completed
                self.status.stringValue = "\(undo ? "已撤销" : "已改名") \(done) 项 · \(batch.errors.count + scan.skipped.count) 项异常"
                self.report = self.status.stringValue + "\n\n" + batch.records.map { r in
                    let state = ["done": "已改名", "undone": "已撤销", "failed": "失败", "planned": "未执行", "pending": "待核实", "undoPending": "撤销待核实"][r.state] ?? r.state
                    return "[\(state)] \(Naming.display(r.source))\n→ \(Naming.display(r.target))" + (r.error.map { "\n\($0)" } ?? "")
                }.joined(separator: "\n\n") + (scan.skipped.isEmpty ? "" : "\n\n重新检查：\n" + scan.skipped.joined(separator: "\n"))
                self.refreshHistory(); self.reload()
                if !batch.errors.isEmpty || !scan.skipped.isEmpty { self.showReport() }
            }
        }
    }
    private func refreshHistory() {
        do { lastUndo = try engine?.latestUndoable() } catch { lastUndo = nil; status.stringValue = "历史记录需要检查"; report += "\n" + error.localizedDescription }
        updateControls()
    }
    @objc private func undoLast() {
        window.makeFirstResponder(nil)
        guard !busy, let batch = lastUndo else { return }
        let alert = NSAlert(); alert.messageText = "撤销上次改名的 \(batch.completed) 项？"
        alert.informativeText = "按反向顺序恢复原名称。如果原位置已有新文件，或项目被移动，撤销会停止并报告，不会覆盖。"
        let text = batch.records.reversed().filter { $0.state == "done" }.map { "\(Naming.display($0.target))\n→ \(Naming.display($0.source))" }.joined(separator: "\n\n")
        alert.accessoryView = textAccessory(text); alert.addButton(withTitle: "确认撤销"); alert.addButton(withTitle: "取消")
        panelOpen = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.panelOpen = false
            guard response == .alertFirstButtonReturn else { return }
            self.busy = true; self.status.stringValue = "正在恢复原名称…"; self.updateControls(); self.table.reloadData()
            self.worker.async {
                do { let undone = try self.engine.undo(batch); DispatchQueue.main.async { self.refreshAfter(undone, undo: true) } }
                catch { DispatchQueue.main.async { self.busy = false; self.reload(); self.showError("撤销未完成", error.localizedDescription); self.refreshHistory() } }
            }
        }
    }
    @objc private func showReport() {
        guard !report.isEmpty else { return }
        let alert = NSAlert(); alert.messageText = "操作结果"; alert.informativeText = "磁盘原名经过重新读取。详细改名记录保存在本机应用支持目录。"
        alert.accessoryView = textAccessory(report); alert.addButton(withTitle: "关闭")
        panelOpen = true; alert.beginSheetModal(for: window) { [weak self] _ in self?.panelOpen = false }
    }
    private func showError(_ title: String, _ message: String) {
        status.stringValue = title
        let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = title; alert.informativeText = Naming.display(message)
        alert.addButton(withTitle: "知道了"); panelOpen = true
        alert.beginSheetModal(for: window) { [weak self] _ in self?.panelOpen = false }
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
