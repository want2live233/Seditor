# Seditor (macOS)

原生 `AppKit` 极简文本编辑器，面向个人使用，强调小体积、低资源占用、良好 CJK 输入体验。

![Dark theme](img/2026-02-19_21-49-11.png)

## 最近更新（2026-03-02）

- 新增编码支持：打开文件自动识别 `UTF-8 / GB18030 / GBK / GB2312`。
- 保存策略调整：已打开文件保存时沿用原编码；新建文件默认 `UTF-8`。
- 修复体验问题：切换标签页/窗口时不再把光标重置到文档开头。
- 修复命名问题：恢复会话后会同步 `Untitled N` 计数器，避免新标签重名。
- 新增编码测试样例：`samples/encodings/` 下提供 GB 系编码测试文本。
- 仓库忽略项：新增 `.gitignore`，忽略 `.build/` 与 `dist/` 构建产物。

## 已实现

- 左侧行号 + 右侧滚动条
- 原生触控板手势滚动
- 自动保存（0.8 秒防抖，写入 `~/Library/Application Support/Seditor/autosave.txt`）
- 打开/保存文件
  - `Cmd+O` 打开
  - `Cmd+S` 保存
  - `Shift+Cmd+S` 另存为
  - 自动识别编码：`UTF-8 / GB18030 / GBK / GB2312`
  - 保存时沿用文件原编码（新文件默认 `UTF-8`）
- 多标签
  - `Cmd+T` 新建标签
  - `Cmd+W` 关闭当前标签
  - `Shift+Cmd+]` / `Shift+Cmd+[` 切换标签
  - 顶部右侧 `+` 按钮新建标签
- 仅渲染可视区行号（大文件更省资源）
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
- `/Users/x/Documents/Personal/Develop/Swift/Seditor/scripts/build_app.sh`
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
