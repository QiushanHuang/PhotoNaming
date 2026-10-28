import AppKit
import NamingCore

final class TimeEditorController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private let mode = NSSegmentedControl(labels: ["统一到指定时间", "按差值平移", "同步到拍摄时间"], trackingMode: .selectOne, target: nil, action: nil)
    private let zone = NSPopUpButton()
    private let date = NSDatePicker()
    private let delta = NSTextField()
    private let unit = NSPopUpButton()
    private let reference = NSPopUpButton()
    private let source = NSTextField(labelWithString: "未选择照片或视频")
    private let status = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "指定时间")
    private let previewText = NSTextView()
    private let fields = TimeField.allCases.map { field -> NSButton in
        let names: [TimeField: String] = [.created: "文件创建时间", .content: "内容拍摄时间", .modified: "文件修改时间"]
        let b = NSButton(checkboxWithTitle: names[field]!, target: nil, action: nil); b.state = .on; return b
    }
    private var choose: NSButton!, reread: NSButton!, preview: NSButton!, apply: NSButton!, close: NSButton!, calibrate: NSButton!, calibrationToggle: NSButton!
    private var dateRow: NSStackView!, shiftRow: NSStackView!, referenceRow: NSStackView!
    private var calibrationVisible = false
    private var infoPopover: NSPopover?
    private var snapshots: [TimeSnapshot] = []
    private var inputs: [URL] = []
    private var plans: [TimePlan] = []
    private var problems: [String] = []
    private var running = false
    private var confirmed = false
    private let worker = DispatchQueue(label: "studio.qiushan.PhotoNaming.time", qos: .userInitiated)
    private let engine: TimeEngine
    var changed = false
    private var currentZone: TimeZone { TimeZone(identifier: zone.titleOfSelectedItem ?? "") ?? .current }
    private var currentMode: TimeMode { TimeMode(rawValue: mode.selectedSegment) ?? .set }

    init(journalDirectory: URL? = nil) throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        engine = try TimeEngine(journalDirectory: journalDirectory ?? support.appendingPathComponent("PhotoNaming/TimeHistory"))
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640), styleMask: [.titled], backing: .buffered, defer: false)
        super.init(window: w); w.title = "修改照片时间"; w.delegate = self
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func row(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views); s.orientation = .horizontal; s.spacing = 12; s.alignment = .centerY; return s
    }
    private func spacer() -> NSView {
        let view = NSView(); view.setContentHuggingPriority(.defaultLow, for: .horizontal); return view
    }
    private func text(_ s: String, bold: Bool = false) -> NSTextField {
        let f = NSTextField(wrappingLabelWithString: s); f.font = bold ? .boldSystemFont(ofSize: 16) : .systemFont(ofSize: 12); return f
    }
    private func button(_ s: String, _ action: Selector) -> NSButton { NSButton(title: s, target: self, action: action) }
    private func build() {
        let body = NSStackView(); body.orientation = .vertical; body.alignment = .leading; body.spacing = 12
        body.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24); window!.contentView = body
        func add(_ v: NSView) { body.addArrangedSubview(v); v.translatesAutoresizingMaskIntoConstraints = false; v.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -48).isActive = true }
        add(text("修改时间", bold: true))
        choose = button("选择照片或文件夹…", #selector(chooseFiles)); close = button("关闭", #selector(dismiss))
        reread = button("重新读取", #selector(reloadSources))
        choose.toolTip = "选择文件夹时会递归读取其中支持的照片和视频。"
        choose.setAccessibilityHelp(choose.toolTip)
        source.lineBreakMode = .byTruncatingMiddle; add(row([choose, reread, source, spacer()]))
        mode.selectedSegment = 0; mode.target = self; mode.action = #selector(optionsChanged); add(mode)
        for f in fields { f.target = self; f.action = #selector(optionsChanged) }
        let info = NSButton(image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "时间字段说明")!, target: self, action: #selector(showFieldInfo(_:)))
        info.isBordered = false; info.toolTip = "文件时间保存在磁盘属性中，拍摄时间保存在媒体文件中。"
        info.setAccessibilityLabel("时间字段说明"); info.setAccessibilityHelp(info.toolTip)
        add(row([text("修改字段")] + fields + [info, spacer(), text("时区"), zone]))
        var zones = [TimeZone.current.identifier, "Asia/Shanghai", "Asia/Singapore", "Asia/Jakarta", "UTC"]
        zones = zones.enumerated().filter { i, v in !zones.prefix(i).contains(v) }.map(\.element)
        zone.addItems(withTitles: zones); zone.target = self; zone.action = #selector(zoneChanged)
        zone.toolTip = "用于显示时间，并解释缺少时区信息的拍摄时间。"
        zone.setAccessibilityLabel("时区"); zone.setAccessibilityHelp(zone.toolTip)
        date.datePickerStyle = .textFieldAndStepper; date.datePickerElements = [.yearMonthDay, .hourMinuteSecond]; date.timeZone = currentZone
        date.dateValue = Date(); date.target = self; date.action = #selector(optionsChanged)
        date.setAccessibilityLabel("指定时间")
        dateRow = row([dateLabel, date, spacer()]); add(dateRow)
        delta.widthAnchor.constraint(equalToConstant: 120).isActive = true; delta.delegate = self
        delta.placeholderAttributedString = NSAttributedString(string: "输入差值", attributes: [.foregroundColor: NSColor.labelColor.withAlphaComponent(0.75)])
        delta.toolTip = "正数向后，负数向前。"
        delta.setAccessibilityLabel("平移差值"); delta.setAccessibilityHelp(delta.toolTip)
        unit.addItems(withTitles: ["小时", "分钟", "秒"]); unit.target = self; unit.action = #selector(optionsChanged)
        unit.setAccessibilityLabel("差值单位")
        calibrationToggle = button("用参考照片计算…", #selector(toggleCalibration))
        shiftRow = row([text("平移差值"), delta, unit, calibrationToggle, spacer()]); add(shiftRow)
        reference.widthAnchor.constraint(lessThanOrEqualToConstant: 450).isActive = true
        reference.target = self; reference.action = #selector(optionsChanged)
        reference.setAccessibilityLabel("参考照片")
        calibrate = button("计算差值", #selector(calculateDelta))
        referenceRow = row([text("参考照片"), reference, calibrate, spacer()]); add(referenceRow)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false; scroll.borderType = .lineBorder
        previewText.isEditable = false; previewText.isSelectable = true; previewText.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewText.isVerticallyResizable = true; previewText.isHorizontallyResizable = false; previewText.autoresizingMask = [.width]
        previewText.textContainerInset = NSSize(width: 12, height: 12)
        previewText.textContainer?.widthTracksTextView = true; scroll.documentView = previewText
        add(scroll); scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        status.maximumNumberOfLines = 2; status.lineBreakMode = .byTruncatingTail; add(status)
        preview = button("预览修改", #selector(makePreview)); apply = button("写入修改", #selector(writeChanges))
        add(row([close, spacer(), preview, apply]))
        update()
    }
    @objc private func showFieldInfo(_ sender: NSButton) {
        let message = NSTextField(wrappingLabelWithString: "文件创建和修改时间保存在磁盘属性中；拍摄时间保存在照片或视频中。同步模式使用各文件自己的拍摄时间。")
        message.font = .systemFont(ofSize: 13)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        content.addSubview(message); message.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([message.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14), message.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14), message.centerYAnchor.constraint(equalTo: content.centerYAnchor)])
        let controller = NSViewController(); controller.view = content
        let popover = NSPopover(); popover.contentViewController = controller; popover.behavior = .transient
        infoPopover = popover; popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
    @objc private func toggleCalibration() {
        calibrationVisible.toggle(); update()
    }
    func load(_ urls: [URL]) {
        guard !running else { return }; inputs = urls; running = true; plans = []; snapshots = []; confirmed = false; update()
        apply.title = "写入修改"
        status.stringValue = "正在扫描并读取拍摄时间…"
        let z = currentZone
        worker.async { [weak self] in
            guard let self else { return }
            let found = TimeEngine.collect(urls)
            var rows: [TimeSnapshot] = [], errors: [String] = []
            for (i, url) in found.enumerated() {
                do { rows.append(try self.engine.read(url, zone: z)) }
                catch { errors.append(url.path + "：" + error.localizedDescription) }
                if i % 10 == 0 { DispatchQueue.main.async { self.status.stringValue = "正在读取 \(i + 1) / \(found.count)…" } }
            }
            DispatchQueue.main.async {
                self.snapshots = rows; self.problems = errors; self.running = false
                self.source.stringValue = "\(rows.count) 个媒体文件" + (errors.isEmpty ? "" : " · \(errors.count) 项读取异常")
                self.reference.removeAllItems(); self.reference.addItems(withTitles: rows.enumerated().map { "\($0.offset + 1). " + URL(fileURLWithPath: $0.element.path).lastPathComponent })
                self.showCurrent(); self.update()
            }
        }
    }
    @objc private func reloadSources() { if !inputs.isEmpty { load(inputs) } }
    @objc private func chooseFiles() {
        guard !running else { return }
        let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = true; p.allowsMultipleSelection = true
        p.beginSheetModal(for: window!) { [weak self] response in if response == .OK { self?.load(p.urls) } }
    }
    private func showCurrent() {
        previewText.string = snapshots.map { s in
            "\(s.path)\n  文件创建：\(TimeText.string(s.created, zone: currentZone))\n  内容拍摄：\(TimeText.string(s.content, zone: currentZone))\n  文件修改：\(TimeText.string(s.modified, zone: currentZone))"
        }.joined(separator: "\n\n") + (problems.isEmpty ? "" : "\n\n读取异常：\n" + problems.joined(separator: "\n"))
        status.stringValue = inputs.isEmpty || !snapshots.isEmpty ? "" : "未找到可处理的媒体文件。支持 JPEG、HEIC、ARW、MP4、MOV 等；跳过隐藏项和符号链接。"
    }
    private func update() {
        let shift = currentMode == .shift, sync = currentMode == .sync
        shiftRow.isHidden = !shift
        referenceRow.isHidden = !shift || !calibrationVisible
        dateRow.isHidden = sync || (shift && !calibrationVisible)
        dateLabel.stringValue = shift ? "正确时间" : "指定时间"
        date.setAccessibilityLabel(dateLabel.stringValue)
        fields[1].isHidden = sync
        calibrationToggle.title = calibrationVisible ? "收起参考照片" : "用参考照片计算…"
        reread.isEnabled = !running && !inputs.isEmpty
        for v in [choose!, preview!, close!, calibrate!, calibrationToggle!, mode, zone, date, delta, unit, reference] as [NSControl] { v.isEnabled = !running }
        for (i, f) in fields.enumerated() { f.isEnabled = !running && !(sync && TimeField.allCases[i] == .content) }
        date.isEnabled = !running && !sync; delta.isEnabled = !running && shift; unit.isEnabled = !running && shift
        reference.isEnabled = !running && shift && !snapshots.isEmpty; calibrate.isEnabled = reference.isEnabled
        preview.isEnabled = !running && !snapshots.isEmpty && !confirmed
        apply.isEnabled = !running && !plans.isEmpty && !confirmed
        preview.bezelColor = apply.isEnabled ? nil : .controlAccentColor
        apply.bezelColor = apply.isEnabled ? .controlAccentColor : nil
    }
    @objc private func optionsChanged() {
        guard !running else { return }
        let hadPreview = !plans.isEmpty
        plans = []; apply.title = "写入修改"
        if confirmed {
            snapshots = []; reference.removeAllItems(); source.stringValue = "请重新读取最新时间"; confirmed = false
            status.stringValue = "请重新读取后预览。"
        } else {
            showCurrent()
            if hadPreview { status.stringValue = "设置已更改，请重新预览。" }
        }
        update()
    }
    func controlTextDidChange(_ obj: Notification) { optionsChanged() }
    @objc private func zoneChanged() {
        date.timeZone = currentZone
        // Missing EXIF offsets were interpreted in the previous chosen timezone.
        // Reload snapshots so changing the timezone cannot reuse that assumption.
        let urls = snapshots.map { URL(fileURLWithPath: $0.path) }
        if !urls.isEmpty { load(urls) } else { optionsChanged() }
    }
    @objc private func calculateDelta() {
        let index = reference.indexOfSelectedItem
        guard snapshots.indices.contains(index), let original = snapshots[index].content else { showError("参考照片没有拍摄时间，无法计算差值。"); return }
        unit.selectItem(at: 2); delta.stringValue = String(format: "%.0f", date.dateValue.timeIntervalSince(original)); optionsChanged()
        status.stringValue = "已计算差值：\(delta.stringValue) 秒（正确时间 − 原拍摄时间），请预览整批结果。"
    }
    @objc private func makePreview() {
        guard !running, !confirmed else { return }
        do {
            let selected = Set(zip(TimeField.allCases, fields).filter { $0.1.state == .on }.map(\.0))
            let n = Double(delta.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            if currentMode == .shift && (n == nil || !n!.isFinite) { throw NamingError("请输入有效的平移差值，例如16或-2。") }
            let multiplier: Double = unit.indexOfSelectedItem == 0 ? 3600 : (unit.indexOfSelectedItem == 1 ? 60 : 1)
            let request = TimeRequest(mode: currentMode, fields: selected, target: Date(timeIntervalSince1970: floor(date.dateValue.timeIntervalSince1970)), delta: currentMode == .shift ? n! * multiplier : 0, zone: currentZone)
            var ready: [TimePlan] = [], errors = problems
            for s in snapshots {
                do { ready.append(try TimePlanner.plan(s, request: request)) }
                catch { errors.append(s.path + "：" + error.localizedDescription) }
            }
            plans = ready
            previewText.string = ready.map { p in
                "\(p.before.path)\n  文件创建：\(TimeText.string(p.before.created, zone: currentZone)) → \(TimeText.string(p.created, zone: currentZone))\n  内容拍摄：\(TimeText.string(p.before.content, zone: currentZone)) → \(TimeText.string(p.content, zone: currentZone))\n  文件修改：\(TimeText.string(p.before.modified, zone: currentZone)) → \(TimeText.string(p.modified, zone: currentZone))"
            }.joined(separator: "\n\n") + (errors.isEmpty ? "" : "\n\n以下项目不执行：\n" + errors.joined(separator: "\n"))
            status.stringValue = "\(ready.count) 项可写入 · \(errors.count) 项异常"
            apply.title = "写入 \(ready.count) 项"; update()
        } catch { showError(error.localizedDescription) }
    }
    @objc private func writeChanges() {
        guard !running, !confirmed, !plans.isEmpty else { return }
        let alert = NSAlert(); alert.messageText = "写入预览中的 \(plans.count) 个文件？"
        alert.alertStyle = .warning
        alert.informativeText = "确认后立即修改时间。时间修改无法撤销，不保留媒体备份；也可能影响先前改名的撤销。"
        alert.addButton(withTitle: "确认写入"); alert.addButton(withTitle: "返回预览")
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }; self.execute()
        }
    }
    private func execute() {
        running = true; update(); let work = plans
        status.stringValue = "正在写入并核验…"
        worker.async { [weak self] in
            guard let self else { return }
            do {
                let outcomes = try self.engine.execute(work) { i, n in DispatchQueue.main.async { self.status.stringValue = "正在写入并核验 \(i) / \(n)…" } }
                DispatchQueue.main.async {
                    self.running = false; self.confirmed = true; self.changed = true; self.plans = []
                    self.previewText.string = outcomes.map { "[\($0.success ? "成功" : "失败")] \($0.plan.before.path)\n\($0.message)" }.joined(separator: "\n\n")
                    self.status.stringValue = "完成：\(outcomes.filter(\.success).count) 项成功，\(outcomes.filter { !$0.success }.count) 项失败。再次操作请点击重新读取。"
                    self.update()
                }
            } catch {
                DispatchQueue.main.async { self.running = false; self.changed = true; self.confirmed = true; self.plans = []; self.update(); self.showError("执行中断，请重新读取文件核实已完成项。\n" + error.localizedDescription) }
            }
        }
    }
    private func showError(_ message: String) {
        let a = NSAlert(); a.messageText = "请检查时间设置或处理结果"; a.informativeText = message; a.addButton(withTitle: "知道了"); a.beginSheetModal(for: window!)
    }
    @objc private func dismiss() {
        guard !running, let w = window else { return }
        w.sheetParent?.endSheet(w)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !running }
}
