# DeepSeek Cost Widget  /  DeepSeek 费用桌面小组件

[English](#english) | [中文](#中文)

---

## English

A native macOS menu bar app + desktop widget for monitoring your DeepSeek API usage and costs in real time.

### Features

- **Menu bar panel** — click the icon to see balance, today's cost, monthly cost, and per-model breakdown
- **Desktop Widget** — all three widget sizes (small/medium/large) with charts and progress bars
- **Built-in settings** — API key, currency, refresh interval all in the popover panel
- **Auto refresh** — configurable timer keeps your data up to date
- **Zero dependencies** — pure SwiftUI, no third-party packages

### Requirements

- macOS 14.0+
- Swift 5.9+ (macOS 自带 Command Line Tools 即可，**不需要 Xcode**)

### Getting Started

```bash
# 1. Clone
git clone https://github.com/alazymerlin/DeepSeekCostWidget.git
cd DeepSeekCostWidget

# 2. 一键编译 + 打包 DMG（无需 Xcode）
chmod +x deploy.command
./deploy.command
# 产物: 桌面 DeepSeekCostWidget.dmg

# 3. 安装
#    双击 DMG → 拖 App 到 /Applications
#    首次打开: 右键(或 Control+点击) App → 打开 → 仍要打开
```

> 若提示缺少命令行工具，运行 `xcode-select --install`

### Build with Xcode (optional)

项目同时保留了 Xcode 工程，可构建菜单栏 App + 桌面小组件：

```bash
brew install xcodegen
xcodegen generate
open DeepSeekCostWidget.xcodeproj
# 注意：小组件仅在 Release 配置下工作
# Cmd+Shift+, → Edit Scheme → Run → Build Configuration → Release
# 两个 target 均需选择 Team，并配置相同的 App Groups
```

### Configure API Key

1. Visit https://platform.deepseek.com → API Keys → Create an API Key
2. Run the app, click the menu bar icon → **Settings** tab
3. Paste your API key, choose currency and refresh interval

### Calibrate Model Breakdown (optional)

Total cost is tracked automatically from your balance — no setup needed.
To split it per model, import a usage export:

1. Go to https://platform.deepseek.com/usage → **Export**
2. In the app → Settings → **Import**, select the downloaded `cost-*.csv` and `amount-*.csv`
3. Model ratios are calibrated once; no need to re-import monthly

### Add Widget to Desktop

- Right-click desktop → Edit Widgets
- Search for "DeepSeek"
- Drag the widget to your desktop or Notification Center

---

## 中文

一款 macOS 原生菜单栏 App + 桌面小组件，实时监控 DeepSeek API 的费用消耗。

### 功能

- **菜单栏面板** — 点击图标查看余额、今日消耗、累计消耗及模型分布进度条
- **桌面小组件** — 支持小/中/大三种尺寸，带图表和进度条
- **内置设置** — API Key、货币单位、刷新间隔全部在弹出面板内配置
- **定时刷新** — 可配置的自动刷新，数据实时更新
- **零依赖** — 纯 SwiftUI，无第三方包

### 环境要求

- macOS 14.0+
- Swift 5.9+（macOS 自带命令行工具即可，**不需要装 Xcode**）

### 首次运行

```bash
# 1. 克隆
git clone https://github.com/alazymerlin/DeepSeekCostWidget.git
cd DeepSeekCostWidget

# 2. 一键编译 + 打包 DMG（无需 Xcode）
chmod +x deploy.command
./deploy.command
# 产物: 桌面 DeepSeekCostWidget.dmg

# 3. 安装
#    双击 DMG → 拖 App 到 /Applications
#    首次打开: 右键(或 Control+点击) App → 打开 → 仍要打开
```

> 若提示缺少命令行工具，运行 `xcode-select --install`

### 用 Xcode 构建（可选）

项目同时保留了 Xcode 工程，可构建菜单栏 App + 桌面小组件：

```bash
brew install xcodegen
xcodegen generate
open DeepSeekCostWidget.xcodeproj
# 注意：小组件仅在 Release 配置下工作
# Cmd+Shift+, → Edit Scheme → Run → Build Configuration → Release
# 两个 target 均需选择 Team，并配置相同的 App Groups
```

### 配置 API Key

1. 访问 https://platform.deepseek.com → API Keys → 创建 API Key
2. 运行 App，点击菜单栏图标 → **设置** 标签
3. 填入 API Key，选择货币单位和刷新间隔

### 校准模型占比（可选）

总费用靠余额自动追踪，无需配置。若想细分到各模型：

1. 打开 https://platform.deepseek.com/usage → **导出**
2. App 内 → 设置 → **导入**，选择下载的 `cost-*.csv` 和 `amount-*.csv`
3. 模型占比校准一次即可，无需每月重新导入

### 添加小组件到桌面

- 右键桌面 → 编辑小组件
- 搜索 "DeepSeek"
- 拖拽到桌面或通知中心

---

## Project Structure

```
DeepSeekCostWidget/
├── Package.swift                    # SwiftPM manifest (menu bar app)
├── deploy.command                   # 一键编译 + 打包 DMG
├── Sources/DeepSeekCostWidget/      # 菜单栏 App 源码 (SwiftPM)
│   ├── DeepSeekCostWidgetApp.swift  # App entry point
│   ├── MenuBarManager.swift         # NSStatusBar + popover
│   ├── DataManager.swift            # Timer + data coordinator
│   ├── PopoverView.swift            # Menu bar popover panel
│   ├── SettingsView.swift           # Settings view model
│   ├── DeepSeekAPI.swift            # Balance API + model cost split
│   ├── UsageCSV.swift               # CSV export parser
│   ├── AppGroup.swift               # UserDefaults + Keychain storage
│   ├── Models.swift                 # Data models
│   └── Strings.swift                # zh/en localization
│
├── project.yml                      # xcodegen config (Xcode build)
├── Shared/                          # Shared code (App + Widget)
├── App/                             # Host App (Xcode target)
└── Widget/                          # Widget Extension (Xcode target)
    ├── WidgetBundle.swift           # Widget entry
    ├── Provider.swift               # TimelineProvider
    ├── WidgetEntryView.swift        # Size router
    ├── SmallWidgetView.swift        # Small widget
    ├── MediumWidgetView.swift       # Medium widget
    └── LargeWidgetView.swift        # Large widget
```

## License

MIT
