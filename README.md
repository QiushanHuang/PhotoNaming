<a id="english"></a>

<p align="center">
  <img src="assets/branding/logo.png" width="148" alt="PhotoNaming — a folder with a confirmed naming label">
</p>

<h1 align="center">PhotoNaming · 照片命名</h1>

<p align="center"><strong>Organize by date. Find it by name.</strong></p>

[![English](https://img.shields.io/badge/Language-English-24292f)](#english)
[![简体中文](https://img.shields.io/badge/语言-简体中文-1677ff)](#中文)

[![Release](https://img.shields.io/github/v/release/QiushanHuang/PhotoNaming)](https://github.com/QiushanHuang/PhotoNaming/releases)
[![CI](https://github.com/QiushanHuang/PhotoNaming/actions/workflows/ci.yml/badge.svg)](https://github.com/QiushanHuang/PhotoNaming/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)](https://github.com/QiushanHuang/PhotoNaming/releases/latest)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-0d9488)](https://github.com/QiushanHuang/PhotoNaming/releases/latest)
[![Swift 6+](https://img.shields.io/badge/Swift-6%2B-f05138?logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Turn inconsistent file and folder names into clear dates, events, places and notes.**
PhotoNaming is a native macOS app that puts the original name beside six editable
fields, highlights the items that need attention, and writes your reviewed changes
back to the actual files. Everything stays on your Mac.

## Why choose PhotoNaming

A photo collection can contain `2026.9.20 Trip`, `New folder`, and neatly organized
folders at the same time. Some need a date, some need a title, and others need no
change at all. Applying one text replacement to the whole collection leaves
those different decisions to you.

PhotoNaming brings those decisions into one table:

- **Fix only what needs fixing.** Filter non-compliant names and keep already
  compliant rows read-only. Useful values are parsed for you; unknown dates stay
  blank for your review.
- **Work with meaningful fields.** Fill in dates, titles and notes instead of
  assembling separators or writing a renaming expression. Edit individual rows
  or apply the same value to selected fields across several rows.
- **Keep control when names reach the disk.** See original and proposed names
  before confirming. Existing targets are not overwritten, results are reported
  per item, and completed renames have persistent undo records.

### Where common approaches become extra work

| Approach | Friction in a mixed collection | PhotoNaming's advantage |
| --- | --- | --- |
| Rename folders one by one in Finder | Repeating dates and separators, then manually checking consistency | Six structured fields, calendar validation and automatic formatting |
| Simple find/replace, prefixing or numbering | Different missing dates and titles need different corrections | Per-row repair alongside selective batch field assignment |
| Plan names in a separate spreadsheet | The plan still has to be transferred to the right files | Original names, editable fields and confirmed disk changes in one workflow |
| Write a one-off script | Preview, collision checks, partial-result reporting and undo need to be implemented | These steps are built into the application |

### A good fit for

- **Travel and family collections:** standardize dates, events and locations
  across folders gathered from different occasions.
- **An old photo archive:** quickly separate consistent names from the backlog
  and complete missing information without redoing the whole collection.
- **Study and project folders:** apply a shared date/title convention while
  keeping a different secondary title or note for each item.

**The workflow:** import → filter → fill in fields → preview → confirm.
Use the same date and title convention across your collection, with individual
places and notes that make each folder easy to recognize.

![PhotoNaming showing original-name status and six naming fields](docs/images/app.png)

*A collection at a glance: organized folders above, names ready to complete below.
The interface is Chinese; the steps below include English translations of each button.*

## Install

Download the **Apple Silicon / arm64** package from
[the latest release](https://github.com/QiushanHuang/PhotoNaming/releases/latest).
Runs on **Apple Silicon Macs with macOS 14 or later**.

- **DMG:** open the disk image and drag `照片命名.app` to Applications, then eject it.
- **ZIP:** unzip, then move `照片命名.app` to Applications or another folder you own.
- Both include an offline bilingual guide and the MIT license. No terminal setup is needed.

**First launch:** this release has not been notarized by Apple, so macOS may ask
you to approve opening it. After downloading from the release page, go to
**System Settings → Privacy & Security → Open Anyway** if prompted.
[Apple's opening instructions](https://support.apple.com/102445) walk through the steps.

Optional download verification, with both release archives and `SHA256SUMS.txt`
in the same folder:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

If you download only one archive, compare its `shasum -a 256` output with its
matching line in `SHA256SUMS.txt`.

## Start here

1. Drag folders/files into the drop area, or click **选择文件或文件夹…** (Choose files or folders).
   By default, only the items you import are checked. Enable **包含子文件夹**
   (Include subfolders) and/or **包含内部文件** (Include contained files) **before**
   importing when you want recursive scanning.
2. Select **未符合** (Non-compliant). Gray columns retain the original name and
   status; blue columns contain the parsed fields. Known values are retained;
   unknown dates remain blank.
3. Fill in the fields. Use **⌘ / ⇧** to select multiple rows and **批量赋值…**
   (Batch assign) to replace only the fields you check. A checked blank value
   clears that field; unchecked fields keep their values.
4. Select the rows to rename. **选择可改名项** selects valid non-compliant rows in
   the current filter. Click **预览重命名** (Preview), review the names and locations,
   then **确认并重命名** (Confirm and rename).
5. Review the updated list: successfully organized items move to **已符合**
   (Compliant). To restore their previous names, click **撤销上次改名…** (Undo last
   rename), review the list and confirm.

| Interface label | Meaning |
| --- | --- |
| 全部 / 已符合 / 未符合 | All / compliant / non-compliant original names |
| 原文件状态 | Original status: compliance and original file/folder name |
| 解析状态 | Parsed fields: year, month, day, primary title, secondary title, note |
| 移出列表 | Clear a row from the list while keeping the file in place |
| 在 Finder 中显示 | Reveal the selected item in Finder (right-click a row) |
| 查看结果 | View completed, failed or skipped operations |

Find more examples and troubleshooting steps in the [user guide](docs/USER_GUIDE.md).
Finish and confirm your edits before closing the app; drafts last for the current
session. Completed rename records are saved for later undo.

## Naming rule

```text
YYYY-MM-DD_primary-title_secondary-title_note.ext
```

Date and primary title are required; secondary title and note are optional.
The last file extension is preserved. Folders are not split at a dot.
Trailing empty fields are omitted; an empty field in the middle keeps its position.

| Fields | Actual disk name |
| --- | --- |
| Date + primary title | `2026-09-20_Family gathering` |
| Add a secondary title | `2026-09-20_Family gathering_Garden` |
| Note with no secondary title | `2026-09-20_Family gathering__Favorites` |
| A photo file | `2026-09-20_Family gathering_Garden_Favorites.jpg` |

Type the date, titles and note into their own cells; PhotoNaming adds the
underscores to the saved name and displays them as spaces in the table.
Dates already present in a name are filled in for you to review. For an undated
folder, enter the date you want to use for that collection. Calendar validation
helps catch invalid dates before you rename.

## Check results and restore names

**查看结果** (View results) shows which items were renamed and which need attention.
If a proposed name already exists, choose a different title or note for that item.
If a file has moved since you imported it, import its current location and try again.
Successful changes stay in place when another item fails, so you can work through
the remaining items using the result list.

**撤销上次改名…** (Undo last rename) restores a batch's previous names, including
nested folders. If an original location is now occupied or a file has moved,
undo pauses and identifies the item to check. Resolve it before retrying.

Hidden items, symbolic links, special files and application/file packages are
left out of the import list; the result panel explains any skipped items.
For connection-dependent storage, work on a local copy before syncing the
organized collection back. You can also use the file picker to import a collection.

Rename history is saved in `~/Library/Application Support/PhotoNaming/History/`,
so you can undo after reopening the app. Keep this folder for recovery; its records
include your file paths. See the [user guide](docs/USER_GUIDE.md) for detailed
recovery steps and the [release notes](docs/releases/v1.0.0.md) for compatibility details.

## Build and contribute

Requires macOS, **Xcode 16+ / Swift 6+** and Python 3 for documentation checks.
There are no third-party package dependencies.

```sh
git clone https://github.com/QiushanHuang/PhotoNaming.git
cd PhotoNaming
swift test
swift test -c release
python3 scripts/check-docs.py
bash scripts/build-app.sh
bash scripts/verify-app.sh
open dist/照片命名.app
```

`bash scripts/package-release.sh` creates the distributable archives and checksums.
See [Contributing](CONTRIBUTING.md), [Changelog](CHANGELOG.md),
[security and privacy](SECURITY.md) and [v1.0.0 release notes](docs/releases/v1.0.0.md).

Created and maintained by **[Qiushan · @QiushanHuang](https://github.com/QiushanHuang)**.
See [contributors and attribution](CONTRIBUTORS.md). Licensed under the
[MIT License](LICENSE). The [logo and design brief](assets/branding/README.md)
are included in the repository.

---

<a id="中文"></a>

## 中文

<p align="center">
  <img src="assets/branding/logo.png" width="148" alt="照片命名 — 文件夹、命名标签与确认勾号">
</p>

<h2 align="center">照片命名 · PhotoNaming</h2>

<p align="center"><strong>按日期整理，凭名字找到。</strong></p>

[![English](https://img.shields.io/badge/Language-English-24292f)](#english)
[![简体中文](https://img.shields.io/badge/语言-简体中文-1677ff)](#中文)

**把混乱的文件名拆成清楚的日期、事件、地点和备注，再确认写回真实文件。**
PhotoNaming 是一个原生 macOS 命名工具：左边保留原名，右边像表格一样填写六个字段，
先筛出需要处理的项目，再预览和确认改名。整个过程都在你的 Mac 上完成。

### 为什么需要它，为什么选它

一批照片文件夹里，可能同时存在 `2026.9.20 旅行`、`新建文件夹`，以及已经整理好的规范名称。
有些缺日期，有些缺主题，有些完全不需要改。面对这种情况，统一替换一段文字，
仍然需要你逐个判断每个名字应该表达什么。

PhotoNaming 把这些判断集中到一张表里，主要解决三件事：

- **只整理有问题的部分。** 一键筛出未符合项，已符合项完整解析并保持只读。
  能识别的内容保留，不知道的日期留给你确认，减少重复录入。
- **填写信息，少操心格式。** 直接填日期、标题、备注，不必逐个拼下划线或编写改名表达式。
  每行可以单独修正，也能只对选中的几列统一赋值。
- **改之前看得清，改之后有记录。** 原名和新名先对照预览，确认后才写入。
  同名不覆盖，逐项报告结果，已完成操作保留可跨重启使用的撤销记录。

### 常见方案的痛点，我们怎样解决

| 常见做法 | 面对混合命名时的麻烦 | PhotoNaming 的优势 |
| --- | --- | --- |
| 在 Finder 里逐个改名 | 反复输入日期与分隔符，还要自己检查是否统一 | 六字段填写、日期校验、自动生成规范名称 |
| 简单批量替换、加前缀或编号 | 不同项目缺少的信息不同，一条规则难以完成逐项修正 | 单行修正与按字段批量赋值结合 |
| 先在表格里列好新名字 | 还要把结果准确对应并写回磁盘，计划与执行分成两步 | 原名、编辑和确认写回放在同一个流程里 |
| 自己写一次性脚本 | 还需实现预览、冲突检查、部分失败处理与撤销记录 | 这些步骤已集成，按界面操作即可 |

### 哪些场景值得用

- **旅行与家庭照片：** 不同活动留下的文件夹日期写法各异，需要统一日期、事件与地点。
- **积累多年的照片归档：** 先把已经规范的部分筛开，只补齐剩余文件夹的信息。
- **学习与项目资料：** 统一日期和主题，同时为各个项目保留不同的二级标题与备注。

**使用流程：导入 → 筛选 → 填写 → 预览 → 确认改名。**
为整批资料统一日期与标题格式，再用各自的地点和备注区分内容，日后浏览和查找更清楚。

![照片命名：原文件状态与六个解析字段](docs/images/app.png)

*一眼看清整理进度：上方是已规范的文件夹，下方直接补齐待整理的名称。*

### 安装

从[最新发布页](https://github.com/QiushanHuang/PhotoNaming/releases/latest)下载
**Apple Silicon / arm64** 安装包，适用于运行 **macOS 14 或更新版本**的 Apple Silicon Mac。

- **DMG：** 打开磁盘映像，将 `照片命名.app` 拖入 Applications，然后推出映像。
- **ZIP：** 解压后，将 `照片命名.app` 移入应用程序目录或你自己的其他目录。
- 两种包都附带中英双语离线说明和 MIT 许可证，无需安装额外运行环境。

**首次打开：** 当前版本未经 Apple 公证，macOS 可能提示你确认是否允许打开。
从发布页下载后，如遇此提示，进入 **系统设置 → 隐私与安全性 → 仍要打开**。
具体步骤见 [Apple 官方说明](https://support.apple.com/102445)。

可将两个安装包和 `SHA256SUMS.txt` 放在同一目录，运行：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

只下载其中一个包时，用 `shasum -a 256 文件名`，与校验文件中的对应行比较即可。

### 快速开始

1. 将文件或文件夹拖到上方区域，或点击 **选择文件或文件夹…**。
   默认只检查拖入项；要检查内部内容，先勾选 **包含子文件夹** 或 **包含内部文件**，再导入。
2. 切换到 **未符合**。灰色两列保留原文件状态与名称，蓝色六列显示解析结果。
   能确定的信息保留，不知道的日期留空。
3. 填写蓝色单元格，用 **Tab** 切换。按 **⌘ / ⇧** 多选，使用 **批量赋值…**
   统一修改勾选字段；勾选后留空表示清空，未勾选的字段保持原值。
4. 选中要改名的行。**选择可改名项** 会选中当前筛选中字段有效的未符合项。
   点击 **预览重命名**，核对原名、新名和位置，然后点击 **确认并重命名**。
5. 整理成功的项目会归入 **已符合**。想恢复原名时，点击 **撤销上次改名…**，
   看一遍恢复清单并确认。

| 界面入口 | 作用 |
| --- | --- |
| 全部 / 已符合 / 未符合 | 按当前文件名分类，随时查看还有哪些项目需要整理 |
| 原文件状态 | 是否按要求、原文件或文件夹名称 |
| 解析状态 | 年、月、日、一级标题、二级标题、备注 |
| 移出列表 | 将项目移出待办列表，文件仍保留在原位置 |
| 在 Finder 中显示 | 右键行，定位真实文件 |
| 查看结果 | 查看完成、失败、跳过及撤销结果 |

更多示例与问题处理见[完整操作指南](docs/USER_GUIDE.md#中文指南)。
关闭应用前，请完成并确认本次编辑；尚未提交的草稿只保留到本次会话结束。
已完成的改名记录会保存下来，供日后撤销使用。

### 命名规则

```text
YYYY-MM-DD_一级标题_二级标题_备注.扩展名
```

日期与一级标题必填；二级标题、备注可空。文件保留最后一个扩展名，文件夹不按点号拆分。
末尾空字段省略，中间空字段保留位置。

| 填写内容 | 真实名称 |
| --- | --- |
| 日期和一级标题 | `2026-09-20_家庭聚会` |
| 增加二级标题 | `2026-09-20_家庭聚会_花园` |
| 没有二级标题，但有备注 | `2026-09-20_家庭聚会__精选` |
| 照片文件 | `2026-09-20_家庭聚会_花园_精选.jpg` |

在各自的单元格里填写日期、标题和备注即可，应用会为真实名称添加下划线，表格中则显示为空格。
名称里已有的日期会自动填入，供你核对；没有日期的文件夹，由你填写这组内容的归属日期。
日期校验会帮你发现无效日期。跨日内容可用起始日，并在备注说明范围。

### 查看结果与恢复原名

点击 **查看结果**，可以看到哪些项目已改好，哪些还需要处理。
如果新名字已经存在，为该项目补充不同的标题或备注；如果文件在导入后被移动，重新导入当前位置即可。
一批项目中出现失败时，已经成功的改名会保留，你可以按结果列表继续处理剩余项目。

点击 **撤销上次改名…** 可以恢复一批项目的原名，也适用于同时整理父子文件夹的情况。
如果原位置已有其他文件，或项目被移到了别处，撤销会暂停并指出需要检查的项目，处理后再重试。

隐藏项目、符号链接、特殊文件及应用包/文件包会从导入列表中跳过，原因可以在结果面板查看。
整理依赖网络连接的资料时，可以先处理本地副本，再将整理好的集合同步回去。
也可以通过文件选择按钮导入资料。

改名记录保存在 `~/Library/Application Support/PhotoNaming/History/`，重新打开应用后仍可用于撤销。
请保留此目录以便恢复，其中会记录你的文件路径。
详细恢复步骤见[操作指南](docs/USER_GUIDE.md#中文指南)，版本适用范围见[发布说明](docs/releases/v1.0.0.md)。

### 开发与贡献

需要 macOS、**Xcode 16+ / Swift 6+**；文档检查使用 Python 3，无第三方包依赖。

```sh
git clone https://github.com/QiushanHuang/PhotoNaming.git
cd PhotoNaming
swift test
swift test -c release
python3 scripts/check-docs.py
bash scripts/build-app.sh
bash scripts/verify-app.sh
open dist/照片命名.app
```

运行 `bash scripts/package-release.sh` 可生成安装包与校验和。
[贡献指南](CONTRIBUTING.md) · [更新记录](CHANGELOG.md) · [安全与隐私](SECURITY.md) ·
[v1.0.0 发布说明](docs/releases/v1.0.0.md)

作者与维护者：**[Qiushan · @QiushanHuang](https://github.com/QiushanHuang)**。
[贡献署名](CONTRIBUTORS.md) · [MIT 许可证](LICENSE) · [Logo 与设计说明](assets/branding/README.md)

[返回英文 / Back to English ↑](#english)
