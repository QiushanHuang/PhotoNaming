# Contributing / 参与贡献

Open an [issue](https://github.com/QiushanHuang/PhotoNaming/issues) to describe a
bug or propose a change. For a bug, include the app/macOS version, expected and
actual behavior, and **synthetic** example names. Do not post personal photo
paths, images, or operation-history JSON containing private paths.

Use Xcode 16 or newer (Swift 6+) on macOS. Before submitting a pull request:

```sh
swift test
swift test -c release
python3 scripts/check-docs.py
bash scripts/build-app.sh
bash scripts/verify-app.sh
```

Keep these contracts intact: no filesystem mutation before confirmation,
no replacement of existing targets, deterministic name parsing/rebuilding,
retained file extensions, and durable per-item rename/undo records. Add focused
regression tests using temporary directories. Changes to naming rules need
examples for blank optional fields, Unicode, invalid dates and collisions.

Update both languages in the **same README**, the user guide and changelog as
needed. Language badges must remain same-page anchors. Keep real user data,
credentials, local build outputs and development-session notes out of commits.

---

欢迎通过 [Issue](https://github.com/QiushanHuang/PhotoNaming/issues) 提交问题或建议。
报告问题时说明应用/macOS 版本、预期与实际结果，并使用虚构文件名复现。
不要公开个人照片、真实路径或含私人路径的历史记录。

在 macOS 上使用 Xcode 16 / Swift 6 或更新工具链，提交 PR 前运行上面的检查。
改名逻辑必须保留确认门槛、同名不覆盖、确定可逆的解析、文件扩展名及逐项恢复记录。
测试使用临时目录；命名规则修改需覆盖可选字段、中文、非法日期与名称冲突。

同步更新同一 README 中的中英文、操作指南与更新记录。语言徽标只在当前页面跳转。
不要提交真实用户数据、凭据、本地构建产物和开发会话记录。
