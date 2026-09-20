<a id="english"></a>

<p align="center">
  <img src="assets/branding/logo.png" width="148" alt="PhotoNaming — a folder with a confirmed naming label">
</p>

<h1 align="center">PhotoNaming · 照片命名</h1>

<p align="center"><strong>Clear names. Confirmed changes. Recoverable mistakes.</strong></p>

[![English](https://img.shields.io/badge/Language-English-24292f)](#english)
[![简体中文](https://img.shields.io/badge/语言-简体中文-1677ff)](#中文)

[![Release](https://img.shields.io/github/v/release/QiushanHuang/PhotoNaming)](https://github.com/QiushanHuang/PhotoNaming/releases)
[![CI](https://github.com/QiushanHuang/PhotoNaming/actions/workflows/ci.yml/badge.svg)](https://github.com/QiushanHuang/PhotoNaming/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)](https://github.com/QiushanHuang/PhotoNaming/releases/latest)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-0d9488)](https://github.com/QiushanHuang/PhotoNaming/releases/latest)
[![Swift 6+](https://img.shields.io/badge/Swift-6%2B-f05138?logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**A native macOS workbench for naming photo folders and files.**
Import a collection, see which names already follow your rule, fill in a small
spreadsheet, and preview every change before it touches the filesystem.
Undo records stay on your Mac and remain available after restarting.

![PhotoNaming showing original-name status and six naming fields](docs/images/app.png)

*Actual application with synthetic demo folders. Version 1.0 uses a Chinese
interface; both English and Chinese instructions are included below.*

## Why PhotoNaming

| What you need | What PhotoNaming provides |
| --- | --- |
| Find inconsistent names | All / compliant / non-compliant filters based on actual names on disk |
| Understand a good name | Automatic parsing into year, month, day, primary title, secondary title and note |
| Repair an incomplete name | Editable cells, keyboard navigation and selective batch field assignment |
| Keep separators out of the way | Underscores hidden in the table and inserted into actual names automatically |
| Know what will happen | Selected-item preview, conflict checks and explicit confirmation |
| Recover from a naming mistake | Persistent, reverse-order undo with no overwrite of existing targets |
| Keep photos local | No account, uploads, telemetry, external runtime or image-content processing |

## Install

Download the **Apple Silicon / arm64** package from
[the latest release](https://github.com/QiushanHuang/PhotoNaming/releases/latest).
Requires **macOS 14 or later**. Intel Mac binaries are not included in this release.

- **DMG:** open the disk image and drag `照片命名.app` to Applications, then eject it.
- **ZIP:** unzip, then move `照片命名.app` to Applications or another folder you own.
- Both include an offline bilingual guide and the MIT license. No terminal setup is needed.

**Signing:** the app is ad-hoc signed, **not Developer ID signed or Apple-notarized**.
If macOS blocks the first launch, verify that you downloaded it from this repository,
then follow Apple's per-app **System Settings → Privacy & Security → Open Anyway**
flow. See [Apple's instructions](https://support.apple.com/102445).
Do not disable Gatekeeper globally.

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
5. Read the result. A successful rename is re-read and parsed from disk before
   its table status becomes compliant. **撤销上次改名…** (Undo last rename) previews
   the reverse operations and asks for confirmation.

| Interface label | Meaning |
| --- | --- |
| 全部 / 已符合 / 未符合 | All / compliant / non-compliant original names |
| 原文件状态 | Original status: compliance and original file/folder name |
| 解析状态 | Parsed fields: year, month, day, primary title, secondary title, note |
| 移出列表 | Remove from the table; does not delete or rename anything |
| 在 Finder 中显示 | Reveal the selected item in Finder (right-click a row) |
| 查看结果 | View completed, failed or skipped operations |

The [detailed user guide](docs/USER_GUIDE.md) covers examples, conflict handling,
undo, privacy and troubleshooting. **Unsubmitted edits are session-only** and
are lost when the app closes; completed-operation history is persistent.

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

The table displays separators as spaces. The real filename retains the underscores.
Do not type underscores inside fields. Dates must be real calendar dates;
creation/modification times are never substituted for an unknown date.
An obvious date in a non-standard name may become a candidate for you to review.

## Rename and recovery behavior

- Changes happen only after you confirm the selected preview. Existing targets
  are not overwritten; duplicate targets within a batch are rejected.
- Source and parent identities are checked again before execution. Files that
  have moved or been replaced are reported instead of silently accepted.
- Nested selections are renamed deepest-first; undo reverses that order.
  Each operation is logged before it starts, and partial failures are reported.
- This is **not an all-or-nothing batch transaction**. Completed operations remain
  completed when a later item fails. Undo stops on a conflict or an externally moved item.
- Hidden items, symbolic links, special files and file/application packages are skipped.
- History is stored in `~/Library/Application Support/PhotoNaming/History/`.
  It contains full paths. Preserve it for cross-session undo and keep it private.

Local APFS workflows have been tested. Network/cloud-mounted drives, very large
collections and a real Finder-to-app drag gesture have not yet been verified;
use the file picker if drag import behaves differently on your setup.

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

[![English](https://img.shields.io/badge/Language-English-24292f)](#english)
[![简体中文](https://img.shields.io/badge/语言-简体中文-1677ff)](#中文)

**一个原生 macOS 照片文件夹与文件命名工作台。**
导入一批文件，筛出不符合规则的名称，像填写表格一样补齐信息，预览并确认后同步到磁盘。
改名记录只保存在本机，退出并重新打开后仍能撤销。

![照片命名：原文件状态与六个解析字段](docs/images/app.png)

*截图来自真实应用，使用专门创建的模拟文件夹；1.0 版应用界面为中文。*

### 能做什么

| 使用场景 | 功能 |
| --- | --- |
| 找出命名不规范的项目 | 按磁盘原名筛选全部、已符合、未符合 |
| 理解已有名称 | 自动解析年、月、日、一级标题、二级标题和备注 |
| 补齐缺失信息 | 单元格编辑、键盘切换、多行选择与按字段批量赋值 |
| 不再手动拼下划线 | 表格隐藏分隔符，真实名称自动保留 |
| 改名前心里有数 | 预览原名、新名和位置，检查冲突，确认后执行 |
| 需要恢复原名 | 持久操作记录、按反向顺序撤销、同名不覆盖 |
| 保持本地与轻量 | 无需账号、不上传文件、不发送遥测、不读取图片内容 |

### 安装

从[最新发布页](https://github.com/QiushanHuang/PhotoNaming/releases/latest)下载
**Apple Silicon / arm64** 安装包，需要 **macOS 14 或更新版本**。
本次发布不包含 Intel Mac 二进制包。

- **DMG：**打开磁盘映像，将 `照片命名.app` 拖入 Applications，然后推出映像。
- **ZIP：**解压后，将 `照片命名.app` 移入应用程序目录或你自己的其他目录。
- 两种包都附带中英双语离线说明和 MIT 许可证，无需安装额外运行环境。

**签名说明：**应用使用本地临时签名，**没有 Developer ID 签名，也未经 Apple 公证**。
若首次打开被拦截，先核实下载来源，再按 Apple 的单应用放行流程进入
**系统设置 → 隐私与安全性 → 仍要打开**。具体操作见 [Apple 官方说明](https://support.apple.com/102445)。
不需要全局关闭 Gatekeeper。

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
5. 完成后重新读取实际名称并解析，通过后才归入 **已符合**。
   需要恢复时点击 **撤销上次改名…**，核对逆向清单并确认。

| 界面入口 | 作用 |
| --- | --- |
| 全部 / 已符合 / 未符合 | 根据磁盘原名分类，草稿不会提前改变原名状态 |
| 原文件状态 | 是否按要求、原文件或文件夹名称 |
| 解析状态 | 年、月、日、一级标题、二级标题、备注 |
| 移出列表 | 只移除表格行，不删除、不改名 |
| 在 Finder 中显示 | 右键行，定位真实文件 |
| 查看结果 | 查看完成、失败、跳过及撤销结果 |

详见[完整操作指南](docs/USER_GUIDE.md#中文指南)。
**尚未提交的编辑仅保留在当前会话，关闭应用会丢失；已完成操作的历史记录会持久保存。**

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

下划线在表格里显示为空格，真实名称中仍然保留；不要在字段内手动填写下划线。
日期必须真实有效，应用不会把创建/修改时间当成未知的拍摄日期。
非标准名称里能识别的日期只作为候选，仍需你核对。跨日内容可用起始日，并在备注说明范围。

### 改名与恢复

- 仅在你确认选中项目的预览后改名。已有目标不覆盖，同一批次产生相同目标会被拦截。
- 执行前再次核对源项目和父目录身份，外部移动或替换会被报告。
- 同时选中父子目录时先改深层项目，撤销时反向处理；每项开始前先保存日志。
- **批量改名不是原子事务**：后续失败不会自动回滚已成功项。撤销遇到冲突或外部移动时停止。
- 隐藏项目、符号链接、特殊文件及应用包/文件包会跳过，并在结果中说明。
- 历史记录位于 `~/Library/Application Support/PhotoNaming/History/`，包含完整路径。
  跨会话撤销需要保留记录，请勿公开自己的日志。

已验证本地 APFS 上的操作。网络盘、云挂载盘、超大集合和真实 Finder 拖拽手势尚未实测；
如果拖入表现异常，可先使用文件选择按钮。

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
