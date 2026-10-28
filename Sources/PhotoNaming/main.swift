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
            ("原文件" as NSString).draw(at: NSPoint(x: 12, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor])
            ("命名字段" as NSString).draw(at: NSPoint(x: split + 12, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.controlAccentColor])
        }
        NSColor.separatorColor.setFill(); NSRect(x: 0, y: 61, width: bounds.width, height: 1).fill()
    }
}
final class EditField: NSTextField {
    var itemID = ""
    var fieldIndex = 0
}

private final class BatchFieldRow: NSStackView {
    let toggle: NSButton
    let input: NSTextField

    init(title: String) {
        toggle = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        input = NSTextField()
        super.init(frame: .zero)
        orientation = .horizontal; alignment = .centerY; spacing = 10
        toggle.widthAnchor.constraint(equalToConstant: 100).isActive = true
        input.widthAnchor.constraint(equalToConstant: 270).isActive = true
        input.isEnabled = false
        input.setAccessibilityLabel(title + "的统一值")
        input.setAccessibilityHelp("勾选后输入；留空会清除该字段。")
        toggle.target = self; toggle.action = #selector(toggleChanged)
        addArrangedSubview(toggle); addArrangedSubview(input)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func toggleChanged() {
        input.isEnabled = toggle.state == .on
        if input.isEnabled { window?.makeFirstResponder(input) }
    }
}

final class AppController: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private let table = NSTableView()
    private let filter = NSSegmentedControl(labels: ["全部 · 0", "已符合 · 0", "未符合 · 0"], trackingMode: .selectOne, target: nil, action: nil)
    private let drop = DropZone()
    private let folders = NSButton(checkboxWithTitle: "包含子文件夹", target: nil, action: nil)
    private let files = NSButton(checkboxWithTitle: "包含内部文件", target: nil, action: nil)
    private let status = label("", size: 13)
    private let detail = label("", size: 12, color: .secondaryLabelColor)
    private let count = label("", size: 12, color: .secondaryLabelColor)
    private let empty = label("还没有导入项目", size: 15, color: .secondaryLabelColor)
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
    private var timeButton: NSButton!
    private var timeEditor: TimeEditorController?
    private var importInfoPopover: NSPopover?

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
        window.title = "照片命名"; window.minSize = NSSize(width: 1040, height: 650)
        window.center(); window.delegate = self; window.tabbingMode = .disallowed
        let body = NSStackView(); body.orientation = .vertical; body.alignment = .leading; body.spacing = 12
        body.edgeInsets = NSEdgeInsets(top: 18, left: 24, bottom: 18, right: 24)
        window.contentView = body
        let brand = NSImageView()
        if let logoURL = Bundle.main.url(forResource: "BrandLogo", withExtension: "png") { brand.image = NSImage(contentsOf: logoURL) }
        brand.widthAnchor.constraint(equalToConstant: 32).isActive = true
        brand.heightAnchor.constraint(equalToConstant: 32).isActive = true
        brand.setAccessibilityElement(false)
        timeButton = button("修改时间…", #selector(editTimes))
        timeButton.toolTip = "修改所选项目的时间；也可在窗口中选择文件。"
        timeButton.setAccessibilityHelp(timeButton.toolTip)
        undoButton = button("撤销上次改名…", #selector(undoLast))
        add(row([brand, label("照片命名", size: 20, weight: .semibold), spacer(), timeButton, undoButton]), to: body)
        importButton = button("选择文件或文件夹…", #selector(chooseFiles))
        let importHelp = NSButton(image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "导入范围说明")!, target: self, action: #selector(showImportInfo(_:)))
        importHelp.isBordered = false
        importHelp.toolTip = "选项只影响后续导入；重新导入可扩大范围。"
        importHelp.setAccessibilityLabel("导入范围说明")
        importHelp.setAccessibilityHelp(importHelp.toolTip)
        let dropLabels = NSStackView(views: [label("将文件或文件夹拖到这里", size: 15, weight: .medium), row([folders, files, importHelp], spacing: 12)])
        dropLabels.orientation = .vertical; dropLabels.alignment = .leading; dropLabels.spacing = 8
        let icon = NSImageView(image: NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)!)
        icon.contentTintColor = .controlAccentColor; icon.widthAnchor.constraint(equalToConstant: 32).isActive = true; icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let dropContent = row([icon, dropLabels, spacer(), importButton], spacing: 18)
        drop.addSubview(dropContent); dropContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([dropContent.leadingAnchor.constraint(equalTo: drop.leadingAnchor, constant: 24), dropContent.trailingAnchor.constraint(equalTo: drop.trailingAnchor, constant: -24), dropContent.centerYAnchor.constraint(equalTo: drop.centerYAnchor)])
        drop.heightAnchor.constraint(equalToConstant: 92).isActive = true
        drop.onDrop = { [weak self] urls in self?.importURLs(urls) }; add(drop, to: body)
        filter.selectedSegment = 0; filter.target = self; filter.action = #selector(filterChanged)
        for i in 0..<3 { filter.setWidth(106, forSegment: i) }
        selectButton = button("选择可改名项", #selector(selectReady))
        batchButton = button("批量赋值…", #selector(batchEdit))
        removeButton = button("移出列表", #selector(removeSelected))
        add(row([filter, count, spacer(), selectButton, batchButton, removeButton], spacing: 8), to: body)
        table.dataSource = self; table.delegate = self; table.rowHeight = 62; table.intercellSpacing = .zero
        table.usesAlternatingRowBackgroundColors = false; table.allowsMultipleSelection = true; table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle; table.allowsColumnReordering = false
        table.style = .plain; table.gridStyleMask = [.solidHorizontalGridLineMask]; table.gridColor = .separatorColor
        let names = ["状态", "原名称"] + fieldTitles
        let widths: [CGFloat] = [106, 290, 74, 72, 72, 180, 170, 170]
        let minimumWidths: [CGFloat] = [88, 180, 70, 70, 70, 140, 125, 125]
        for i in names.indices {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(i)")); column.title = names[i]; column.width = widths[i]; column.minWidth = minimumWidths[i]
            column.resizingMask = [.autoresizingMask, .userResizingMask]
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
        detail.maximumNumberOfLines = 2; detail.lineBreakMode = .byTruncatingTail
        add(detail, to: body)
        previewButton = button("预览重命名…", #selector(preview)); previewButton.bezelColor = .controlAccentColor; previewButton.keyEquivalent = ""
        reportButton = button("查看结果…", #selector(showReport))
        add(row([status, spacer(), reportButton, previewButton]), to: body)
    }
    private func add(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view); view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
    }
    @objc private func showImportInfo(_ sender: NSButton) {
        let message = NSTextField(wrappingLabelWithString: "默认只检查导入的项目。勾选后会在后续导入时包含内部项目；重新导入可扩大范围。")
        message.font = .systemFont(ofSize: 13)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 78))
        content.addSubview(message); message.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([message.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14), message.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14), message.centerYAnchor.constraint(equalTo: content.centerYAnchor)])
        let controller = NSViewController(); controller.view = content
        let popover = NSPopover(); popover.contentViewController = controller; popover.behavior = .transient
        importInfoPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
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
        empty.stringValue = items.isEmpty ? "还没有导入项目" : "此筛选下没有项目"
        updateControls()
    }
    private func updateControls() {
        guard previewButton != nil else { return }
        let editing = selectedEditable
        timeButton.isEnabled = !busy
        count.stringValue = "已选 \(selected.count) 项"
        count.isHidden = selected.isEmpty
        previewButton.title = editing.isEmpty ? "预览重命名" : "预览重命名 · \(editing.count) 项"
        previewButton.isEnabled = !busy && engine != nil && !editing.isEmpty
        batchButton.isEnabled = !busy && !editing.isEmpty
        removeButton.isEnabled = !busy && !selected.isEmpty
        selectButton.isEnabled = !busy && visible.contains { !$0.parsed.compliant && (drafts[$0.id] ?? $0.parsed.fields).errors.isEmpty }
        undoButton.isEnabled = !busy && lastUndo != nil
        importButton.isEnabled = !busy; folders.isEnabled = !busy; files.isEnabled = !busy; filter.isEnabled = !busy; drop.enabled = !busy
        reportButton.isEnabled = !busy && !report.isEmpty
        let invalid = editing.compactMap { item -> (Item, [String])? in
            let errors = (drafts[item.id] ?? item.parsed.fields).errors
            return errors.isEmpty ? nil : (item, errors)
        }
        if let first = invalid.first {
            let prefix = invalid.count > 1 ? "\(invalid.count) 项待检查 · \(first.0.url.lastPathComponent)：" : ""
            detail.stringValue = prefix + first.1.joined(separator: "；")
            detail.textColor = .systemOrange
            detail.isHidden = false
        } else { detail.stringValue = ""; detail.isHidden = true }
    }
    @objc private func editTimes() {
        guard !busy, !panelOpen else { return }
        do {
            let editor = try TimeEditorController(journalDirectory: nil); timeEditor = editor
            let urls = selected.map(\.url)
            busy = true; updateControls()
            window.beginSheet(editor.window!) { [weak self, weak editor] _ in
                guard let self else { return }
                if editor?.changed == true {
                    let currentURLs = self.items.map(\.url)
                    self.worker.async {
                        let scan = Scanner.scan(currentURLs)
                        DispatchQueue.main.async {
                            self.items = scan.items; self.busy = false; self.timeEditor = nil
                            self.reload(); self.status.stringValue = "时间处理结束，已重新读取文件状态"
                        }
                    }
                } else { self.busy = false; self.timeEditor = nil; self.updateControls() }
            }
            if !urls.isEmpty { editor.load(urls) }
        } catch { showError("无法打开时间编辑", error.localizedDescription) }
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
            let name = label(item.url.lastPathComponent, size: 13, weight: .medium)
            let sub = label((item.directory ? "文件夹" : "文件") + " · " + item.url.deletingLastPathComponent().path, size: 11, color: .secondaryLabelColor)
            let content = NSStackView(views: [name, sub]); content.orientation = .vertical; content.alignment = .leading; content.spacing = 4
            container.addSubview(content); content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9), content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8), content.centerYAnchor.constraint(equalTo: container.centerYAnchor), name.widthAnchor.constraint(equalTo: content.widthAnchor), sub.widthAnchor.constraint(equalTo: content.widthAnchor)])
            container.toolTip = item.url.path + "\n" + item.parsed.message
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
            let placeholder = item.parsed.compliant ? "—" : (index < 6 ? "必填" : "")
            field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [.foregroundColor: NSColor.labelColor.withAlphaComponent(0.75)])
            field.setAccessibilityLabel(fieldTitles[index - 2] + "，" + item.url.lastPathComponent)
            container.addSubview(field); field.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 7), field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -7), field.centerYAnchor.constraint(equalTo: container.centerYAnchor), field.heightAnchor.constraint(equalToConstant: 28)])
        }
        return container
    }
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard !busy, let field = obj.object as? EditField,
              let index = visible.firstIndex(where: { $0.id == field.itemID }),
              !table.isRowSelected(index) else { return }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
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
        let alert = NSAlert(); alert.messageText = "为 \(targets.count) 项批量赋值"; alert.informativeText = "只替换勾选的字段；留空会清除该字段。"
        alert.addButton(withTitle: "应用到草稿"); alert.addButton(withTitle: "取消")
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 10; stack.alignment = .leading
        let fieldRows = fieldTitles.map { BatchFieldRow(title: $0) }
        for fieldRow in fieldRows { stack.addArrangedSubview(fieldRow) }
        stack.frame = NSRect(x: 0, y: 0, width: 390, height: 218); alert.accessoryView = stack
        panelOpen = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }; self.panelOpen = false
            guard response == .alertFirstButtonReturn else { return }
            guard fieldRows.contains(where: { $0.toggle.state == .on }) else { return }
            for item in targets {
                var values = self.drafts[item.id] ?? item.parsed.fields
                for i in 0..<6 where fieldRows[i].toggle.state == .on { values.set(i, fieldRows[i].input.stringValue) }
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
                return errors.isEmpty ? nil : item.url.lastPathComponent + "：" + errors.joined(separator: "；")
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
                return "\(index + 1). 原名：\(change.item.url.lastPathComponent)\n    新名：\(change.target.lastPathComponent)\n    原位置：\(change.item.url.deletingLastPathComponent().path)\n    最终位置：\(final)"
            }.joined(separator: "\n\n")
            let alert = NSAlert(); alert.messageText = "确认重命名 \(changes.count) 项？"
            alert.informativeText = "确认后立即重命名；目标已存在时不会覆盖。之后可尝试使用“撤销上次改名”恢复。"
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
                    return "[\(state)] \(r.source)\n→ \(r.target)" + (r.error.map { "\n\($0)" } ?? "")
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
        let text = batch.records.reversed().filter { $0.state == "done" }.map { "\($0.target)\n→ \($0.source)" }.joined(separator: "\n\n")
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
        let alert = NSAlert(); alert.messageText = "操作结果"
        alert.accessoryView = textAccessory(report); alert.addButton(withTitle: "关闭")
        panelOpen = true; alert.beginSheetModal(for: window) { [weak self] _ in self?.panelOpen = false }
    }
    private func showError(_ title: String, _ message: String) {
        status.stringValue = title
        let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = title; alert.informativeText = message
        alert.addButton(withTitle: "知道了"); panelOpen = true
        alert.beginSheetModal(for: window) { [weak self] _ in self?.panelOpen = false }
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
