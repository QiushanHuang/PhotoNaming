# Changelog / 更新记录

## 1.1.0 — 2026-10-28

- Independent photo/video time editor: set one time, shift by an offset or reference
  photo, and sync filesystem creation/modification times to embedded capture time.
- Explicit field selection and timezone, per-file before/after preview, confirmation,
  background execution, read-back verification and separate time-operation logs.
- Bundled ExifTool with upstream license; staged metadata writes preserve unchecked
  file timestamps, with exFAT compatibility and external-change rejection.
- A streamlined main window and mode-specific time controls, with contextual help,
  accessible field labels, adaptive table columns and improved dark-mode readability.
- Starting a field edit selects its row; batch inputs become available when checked.
  Changing time settings clears the previous preview and requires a new preview.
- Rename previews, results and undo lists show the actual names and paths, including
  underscores. Time-write confirmation explains that time edits cannot be undone and
  no permanent media backup is retained.

新增独立时间编辑：统一时间、差值平移/参考校准、文件时间同步到拍摄时间；支持字段勾选、
时区、预览确认、逐项核验与时间日志。随包附带 ExifTool，无需额外安装。精简主界面并按模式
显示时间设置，支持窄窗口和深色外观；开始编辑时选中对应行，批量赋值按勾选启用字段。
改名预览、结果和撤销列表显示真实名称；时间设置改变后须重新预览。时间写入不可撤销，
不会保留长期媒体备份，确认窗口会提示这一后果。

## 1.0.0 — 2026-09-20

- Native macOS file/folder import with optional recursive scanning and duplicate filtering.
- Original-state filters and a grouped eight-column table with six editable naming fields.
- Batch field assignment, explicit rename preview and confirmation, extension preservation.
- Exclusive same-folder renames, source/parent identity checks, persistent undo and partial-result reporting.
- PhotoNaming logo, Dock/app icon, bilingual documentation and same-page language badges.
- Apple Silicon ZIP/DMG packages with offline instructions, license and SHA-256 checksums.
- Debug and optimized-release tests, including Unicode validation and nested-folder rename/undo.

首个版本提供原生导入与可选递归、按原名状态筛选、六字段编辑、批量赋值、确认改名、
扩展名保留、同名不覆盖、持久撤销及部分失败结果。新增完整 Logo、应用图标、中英双语
文档与页内语言跳转，以及含离线说明、许可证和校验和的 Apple Silicon ZIP/DMG 安装包。
