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
- Xcode 15.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Getting Started

```bash
# 1. Clone & generate Xcode project
git clone https://github.com/klinee591-bit/DeepSeekCostWidget.git
cd DeepSeekCostWidget
xcodegen generate
open DeepSeekCostWidget.xcodeproj

# 2. Set your Team in Xcode
#    Both targets → Signing & Capabilities → Team

# 3. Configure App Groups for both targets
#    Add capability "App Groups" and use the same group identifier
```

### Configure API Key

1. Visit https://platform.deepseek.com → API Keys → Create an API Key
2. Run the app, click the menu bar icon → **Settings** tab
3. Paste your API key, choose currency and refresh interval

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
- Xcode 15.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 首次运行

```bash
# 1. 克隆并生成 Xcode 项目
git clone https://github.com/klinee591-bit/DeepSeekCostWidget.git
cd DeepSeekCostWidget
xcodegen generate
open DeepSeekCostWidget.xcodeproj

# 2. 在 Xcode 里选择 Team
#    两个 target → Signing & Capabilities → Team

# 3. 给两个 target 配置 App Groups
#    添加 "App Groups" capability，使用相同的 group 标识
```

### 配置 API Key

1. 访问 https://platform.deepseek.com → API Keys → 创建 API Key
2. 运行 App，点击菜单栏图标 → **设置** 标签
3. 填入 API Key，选择货币单位和刷新间隔

### 添加小组件到桌面

- 右键桌面 → 编辑小组件
- 搜索 "DeepSeek"
- 拖拽到桌面或通知中心

---

## Project Structure

```
DeepSeekCostWidget/
├── project.yml                  # xcodegen project config
├── Shared/                      # Shared code (App + Widget)
│   ├── Models.swift             # Data models
│   ├── AppGroup.swift           # App Groups shared storage
│   └── DeepSeekAPI.swift        # DeepSeek API client
├── App/                         # Host App
│   ├── DeepSeekCostWidgetApp.swift  # App entry point
│   ├── MenuBarManager.swift     # NSStatusBar manager
│   ├── DataManager.swift        # Timer + data coordinator
│   ├── PopoverView.swift        # Menu bar popover panel
│   ├── SettingsView.swift       # Settings (ViewModel)
│   └── App.entitlements
└── Widget/                      # Widget Extension
    ├── WidgetBundle.swift       # Widget entry
    ├── Provider.swift           # TimelineProvider
    ├── WidgetEntryView.swift    # Size router
    ├── SmallWidgetView.swift    # Small widget
    ├── MediumWidgetView.swift   # Medium widget
    ├── LargeWidgetView.swift    # Large widget
    └── Widget.entitlements
```

## License

MIT
