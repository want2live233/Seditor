# Seditor (macOS)

原生 `AppKit` 极简文本编辑器，面向个人使用，强调小体积、低资源占用、良好 CJK 输入体验。

![Dark theme](img/2026-02-19_21-49-11.png)

## 最近更新（2026-04-26）

- 本地化升级：接入 `String Catalog`（`Localizable.xcstrings`），统一中英文文案管理。
- 帮助系统升级：接入 macOS `Help Book`（`SeditorHelp.help`），Help 菜单优先打开系统帮助内容。
- 新增「关闭全部标签页」：支持一次性关闭全部页面（`Option+Cmd+W`）。
- 支持关闭最后一个标签页：当没有打开文件时，显示空状态提示页（可直接点按钮打开文件或新建标签）。
- 调整关闭未保存文件行为：选择 `Don't Save` 时会直接删除该标签对应的 autosave 缓存文件。
- 新增查找能力：`Find / Find Next / Find Previous / Use Selection for Find / Replace / Replace All`。
- 新增 `Go to Line...`（`Cmd+L`）：支持 `line` 和 `line:column` 格式。
- 新增底部状态栏：显示光标 `Ln/Col`，可切换编码（`UTF-8 / GB18030 / GBK / GB2312`）和行尾（`LF / CRLF`）。
- 新增外部文件变更检测：文件被其他程序修改后，聚焦编辑器会提示「重新加载」或「保留当前内容」。
- 修复中文输入法组合输入时的光标偏移：输入汉字时不再出现光标视觉右偏。
- 新增触控板双指捏合缩放字体（并保留菜单字体缩放）。
- 自动保存机制调整：编辑后 `0.8s` 防抖仅写 autosave，显式保存（`Cmd+S`）再写入目标文件，`Undo/Redo` 可正常使用。
- 结构解耦：引入 `WorkspaceController`（标签/会话协调）与 `WorkspacePersistenceService`（会话持久化与恢复）。
- 菜单结构补齐：增加 `File > New`、`Window`、`Help` 等项，进一步贴近 macOS 应用习惯。

## 历史更新（2026-03-03）

- 新增编码支持：打开文件自动识别 `UTF-8 / GB18030 / GBK / GB2312`。
- 保存策略调整：已打开文件保存时沿用原编码；新建文件默认 `UTF-8`。
- 新增标签高亮：当前选中标签的 title 会高亮显示，便于识别当前编辑上下文。
- 修复会话恢复：恢复有源文件的标签时优先读取真实文件内容，读不到时才回退到 autosave，避免误以 autosave 替代原文件。
- 修复体验问题：切换标签页/窗口时不再把光标重置到文档开头。
- 修复命名问题：恢复会话后会同步 `Untitled N` 计数器，避免新标签重名。
- 新增编码测试样例：`samples/encodings/` 下提供 GB 系编码测试文本。
- 仓库忽略项：新增 `.gitignore`，忽略 `.build/` 与 `dist/` 构建产物。
- 修复文件打开错误：解决 `The document “x.txt” could not be opened. Seditor cannot open files in the “text” format.`，现在通过 Finder“打开方式 -> Seditor”可正常打开 `text/txt` 文件，且不再出现同名空白重复标签。

## 已实现

- 左侧行号 + 右侧滚动条
- 原生触控板手势滚动
- 自动保存（0.8 秒防抖，写入 autosave 缓存）
  - 显式保存（`Cmd+S` / `Shift+Cmd+S`）时写入目标文件
  - 会话恢复时：有未保存改动优先恢复 autosave，否则优先读取磁盘文件
  - 关闭未保存标签并选择 `Don't Save` 时删除 autosave 缓存
- 打开/保存文件
  - `Cmd+O` 打开
  - `Cmd+S` 保存
  - `Shift+Cmd+S` 另存为
  - 自动识别编码：`UTF-8 / GB18030 / GBK / GB2312`
  - 保存时沿用文件原编码（新文件默认 `UTF-8`）
- 多标签
  - `Cmd+T` 新建标签
  - `Cmd+W` 关闭当前标签
  - `Option+Cmd+W` 关闭全部标签
  - `Shift+Cmd+]` / `Shift+Cmd+[` 切换标签
  - 顶部右侧 `+` 按钮新建标签
- 无标签空状态页面（提示打开文件或新建标签）
- 编辑菜单能力
  - `Undo / Redo`
  - `Find / Replace`
  - `Go to Line...`（支持 `line:column`）
- 状态栏（光标位置、编码切换、行尾切换）
- 外部文件修改检测与重新加载提示
- 仅渲染可视区行号（大文件更省资源）
- 中文输入法组合输入光标位置修复
- 双指捏合缩放字体
- 主题切换（System/Light/Dark）
- 字体大小调整（View 菜单）

## 运行

```bash
swift run Seditor
```

## 打包 .app（固定图标）

项目已包含固定图标资源：
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Assets/AppIcon.icns`

一键打包：

```bash
cd "/Users/x/Documents/Personal/Develop/Swift/Seditor"
./scripts/build_app.sh
```

输出位置：
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/dist/Seditor.app`

说明：
- 打包脚本会同时拷贝 `Help Book` 资源到 App Bundle：`SeditorHelp.help`。
- Help 菜单会优先使用系统帮助入口；若帮助包缺失则回退到应用内帮助窗口。

## 工具链问题排查

如果你遇到 `Swift` 编译器和 SDK 版本不匹配（`this SDK is not supported by the compiler`），先检查并对齐工具链：

```bash
xcode-select -p
xcodebuild -version
swift --version
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 核心文件

- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Package.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Assets/AppIcon.icns`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Assets/HelpBook/SeditorHelp.help/Contents/Info.plist`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Assets/HelpBook/SeditorHelp.help/Contents/Resources/en.lproj/index.html`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Assets/HelpBook/SeditorHelp.help/Contents/Resources/zh-Hans.lproj/index.html`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/scripts/build_app.sh`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/Resources/Localizable.xcstrings`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/App/Main.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/App/AppDelegate.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/Core/EditorSession.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/Core/EditorTheme.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/Views/EditorTextView.swift`
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/Sources/Seditor/Views/GutterView.swift`

## 测试文件

- 编码测试样例：
  - `/Users/x/Documents/Personal/Develop/Swift/Seditor/samples/encodings/test-gbk.txt`
  - `/Users/x/Documents/Personal/Develop/Swift/Seditor/samples/encodings/test-gb18030.txt`
  - `/Users/x/Documents/Personal/Develop/Swift/Seditor/samples/encodings/test-gb2312.txt`
