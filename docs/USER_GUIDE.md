<a id="english-guide"></a>

# PhotoNaming user guide

[English](#english-guide) · [简体中文](#中文指南)

## Before you start

Download from the [official releases](https://github.com/QiushanHuang/PhotoNaming/releases).
Use an Apple Silicon Mac running macOS 14+. The app interface is Chinese; the
button labels below let English readers follow the same workflow. Start with a
small copied sample if you are still deciding on your naming convention.

Open the DMG, drag `照片命名.app` to Applications, and eject the image; or unzip
the ZIP and move the app to a folder you own. Both packages contain this guide.
The release is ad-hoc signed and not Apple-notarized. For a verified download
blocked on first launch, follow [Apple's per-app instructions](https://support.apple.com/102445):
System Settings → Privacy & Security → Open Anyway. Do not disable global security.

## Choose your scope

Import through the drop area or **选择文件或文件夹…**. By default, a dragged folder
means the folder itself, not every photo inside. Before importing, enable
**包含子文件夹** for descendant folders and/or **包含内部文件** for contained files.
Changing a checkbox does not rescan an existing list: import again to expand it.
Repeated paths are deduplicated. Hidden items, symbolic links, packages and special
files are skipped. **查看结果** explains skipped or unreadable items.

## Read and edit the table

The left group is the on-disk state; the right group is your editable draft.
A compliant row has all six parsed fields, including explicit empty optional
fields shown as `—`. A non-compliant row can contain useful candidate values.
An unknown date remains empty. Editing a draft never changes the original-state
badge until a confirmed rename has actually succeeded.

Date (year/month/day) and primary title are required. Choose an event/subject as
the primary title; use the secondary title for a location or sub-event, and the
note for additional context. You decide the collection's date. For a date range,
use the starting date and explain the range in the note.

Select a row and edit its blue cells. Tab moves between inputs. Select several
rows with ⌘/⇧, then use **批量赋值…**: check only the fields to replace. A checked
blank input clears a value; unchecked fields keep their values. Compliant rows
are read-only in this release.

Underscores and path/control characters cannot be entered into fields. The app
inserts structural underscores automatically. Months and days are padded to two
digits; surrounding whitespace is trimmed. The last extension stays attached to
files; folders retain dots as ordinary name characters.

Examples:

```text
2026-09-20_Trip
2026-09-20_Trip_Beach
2026-09-20_Trip__Favorites
2026-09-20_Trip_Beach_Favorites.jpg
```

The double underscore preserves a missing secondary title. Trailing empty fields
are omitted. All underscores are hidden in table names and previews. Use
**在 Finder 中显示** (right-click a row) to locate the actual item.

## Preview and confirm

Select the rows you intend to change. **选择可改名项** selects valid non-compliant
rows within the current filter. **预览重命名** shows each original name, proposed
name, original folder and final path. Invalid dates, missing required fields,
existing targets, duplicate targets and stale source identities block submission.

**返回编辑** makes no changes. **确认并重命名** performs the reviewed operations.
The app disables edits while a batch runs. It re-reads resulting names to update
compliance. **查看结果** distinguishes success, failure and skipped items.
Removing rows with **移出列表** never removes files from the disk.

## Undo and history

**撤销上次改名…** previews the latest batch that still contains completed changes.
Confirm to restore names in reverse order. A conflict, moved file or replaced
identity stops undo and is reported. The app does not overwrite something newly
created at the original location. After a successful undo, an earlier batch can
become the next undoable batch.

Parents and children can be selected together. Renames run deepest-first and
undo reverses that order. This is not an atomic transaction: inspect partial
results instead of assuming the entire batch either succeeded or rolled back.

History lives at `~/Library/Application Support/PhotoNaming/History/`. It is
necessary for undo after restart and contains private absolute paths. Do not
edit/delete history while an operation is active. Unsubmitted drafts and the
import list are not retained after closing the app.

## Troubleshooting

| Situation | What to do |
| --- | --- |
| A name remains non-compliant | Check the date, required title, separators and empty-field positions. Formatting must round-trip exactly. |
| Two files want the same name | Add a distinct secondary title or note; the app will not silently number them. |
| The source moved or was replaced | Remove the stale row and import the current item again. |
| No rename permission | Check the parent folder's permissions/locked state and import a writable local location. |
| A folder is skipped | Check whether it is hidden, a symlink or a package; read the import result. |
| Undo is blocked | Read the conflicting paths. Resolve the conflict yourself, then retry; do not delete another file blindly. |
| History cannot be saved | Stop and check available disk space and the history folder's permissions. Inspect results before retrying. |
| Drag import does not respond | Use the file chooser. Actual drag gestures and network/cloud filesystems are not yet validated. |

Quit the app to uninstall, then move only the app bundle to Trash. Your photos
remain where they are. Keep the history folder if you may still need recovery;
deleting that folder removes the app's undo records. No account or background
service needs removal.

---

<a id="中文指南"></a>

## 中文指南

[English](#english-guide) · [简体中文](#中文指南)

### 安装与准备

从[官方 Releases](https://github.com/QiushanHuang/PhotoNaming/releases)下载，使用
macOS 14 及以上的 Apple Silicon Mac。打开 DMG，把 `照片命名.app` 拖入应用程序后推出；
也可解压 ZIP，把应用放入自己有权限的目录。初次尝试时可先用一小批复制样例确定命名习惯。

当前包为临时签名、未经 Apple 公证。确认下载来源后，如被首次启动保护拦截，按
[Apple 官方说明](https://support.apple.com/102445)进入「系统设置 → 隐私与安全性 → 仍要打开」。
不要关闭全局系统安全检查。

### 导入范围

拖入或点击 **选择文件或文件夹…**。默认只检查所选项目本身，不自动把文件夹内的照片全部列出。
需要递归时，先勾选 **包含子文件夹** 和/或 **包含内部文件**，再导入。
修改开关不会追溯扫描已有列表，重新导入可以扩大范围；重复路径会去重。
隐藏项目、符号链接、文件包/应用包及特殊文件会跳过；**查看结果** 可查看原因。

### 填写表格

左侧保留磁盘上的原始状态，右侧是待提交草稿。正确名称自动拆成六字段，可选字段为空时显示 `—`。
不规范名称中能识别的信息作为候选保留；不能确定的日期留空。草稿编辑不会提前改变左侧状态。

年、月、日和一级标题必填；一级标题建议为事件或主题，二级标题为地点或子事件，备注补充其他信息。
日期由你决定；跨日内容可以用起始日，并在备注说明范围。应用不会读照片内容或猜测拍摄时间。

选中行后编辑蓝色单元格，用 Tab 切换。⌘/⇧ 多选后点 **批量赋值…**，仅勾选想替换的字段。
勾选后留空会清空，未勾选保留原值。当前版本的已符合行只读。

字段不能包含下划线、路径字符及控制字符。应用自动补齐分隔符，月日补零、去掉首尾空格。
文件保留最后一个扩展名，文件夹中的点号按普通名称处理。

```text
2026-09-20_旅行
2026-09-20_旅行_海边
2026-09-20_旅行__精选
2026-09-20_旅行_海边_精选.jpg
```

中间空字段用两个下划线保留位置，末尾空字段省略。表格和预览隐藏下划线；
右键 **在 Finder 中显示** 可定位真实文件。

### 确认改名

选中要改名的行；**选择可改名项** 只选中当前筛选中字段有效的未符合项。
**预览重命名** 展示原名、新名、原位置和最终位置。日期无效、必填缺失、目标已存在、批内同名，
以及源项目外部变化都会阻止提交。

**返回编辑** 不改变磁盘；**确认并重命名** 才执行。执行期间禁止编辑，结束后重新读取名称判定状态。
**查看结果** 区分成功、失败与跳过；**移出列表** 只删表格行，永远不删除真实文件。

### 撤销与记录

**撤销上次改名…** 展示最近一批仍有已完成项的操作，确认后按反向顺序恢复。
遇到同名冲突、外部移动或替换会停止并报告，不覆盖原位置后来新建的文件。
一批全部撤销后，更早的批次可能成为下一次可撤销对象。

父子目录同时选中时先改深层项，撤销顺序相反。批次不是原子事务，部分成功时请看逐项结果，
不要假设整批自动回滚。

历史记录位于 `~/Library/Application Support/PhotoNaming/History/`，包含完整私人路径，
跨重启撤销需要保留。操作进行中不要修改或删除历史记录。导入列表和未提交草稿不跨会话保存。

### 常见问题

| 情况 | 处理方式 |
| --- | --- |
| 仍显示未符合 | 检查真实日期、一级标题、分隔方式及空字段位置；规范名称必须能准确往返解析 |
| 多个项目生成同名 | 填写不同二级标题或备注；不会自动偷偷添加序号 |
| 原文件已移动或替换 | 将旧行移出，再导入当前位置 |
| 没有改名权限 | 检查父目录权限、锁定状态，先在有权限的本地目录使用 |
| 文件夹被跳过 | 查看是否隐藏、符号链接或文件包，并阅读结果说明 |
| 撤销冲突 | 核对冲突路径，自行处理后重试，不要为了撤销盲目删除另一文件 |
| 日志无法保存 | 检查空间和历史目录权限，阅读结果后再决定是否重试 |
| 拖入没反应 | 使用文件选择器；真实拖拽手势和网络/云挂载盘尚未完成验证 |

卸载时退出应用，将应用本身移到废纸篓即可，照片不受影响。如仍需恢复，保留历史目录；
删除历史目录会失去撤销记录。无需注销账号或卸载后台服务。

[返回英文 / Back to English ↑](#english-guide)
