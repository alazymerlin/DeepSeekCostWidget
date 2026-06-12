# DeepSeek 费用消耗桌面小组件

macOS 原生桌面小组件，展示 DeepSeek API 费用消耗，包含菜单栏 App 和 Widget Extension。

## 环境要求

- macOS 14.0+
- Xcode 15.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 首次运行

### 1. 生成 Xcode 项目

```bash
cd DeepSeekCostWidget
xcodegen generate
open DeepSeekCostWidget.xcodeproj
```

### 2. 配置 App Groups

用 Xcode 打开项目后，配置两个 target 的 App Groups：

- 选择 **DeepSeekCostWidget** target → Signing & Capabilities → **+ Capability** → **App Groups**
- 添加 group: `TQK63XXH38.com.deepseekcostwidget.group`
- 选择 **DeepSeekCostWidgetExtension** target → 同样添加 App Groups
- 确保两个 target 使用**相同的** group

### 3. 设置 App Group Identifier

- 在 Build Settings 中搜索 `AppGroupIdentifier`
- 设置为 `TQK63XXH38.com.deepseekcostwidget.group`

### 4. 配置 API Key

1. 访问 https://platform.deepseek.com → API Keys → 创建 API Key
2. 运行 App，点击菜单栏图标，进入设置面板
3. 填入 API Key，选择货币单位和刷新间隔

### 5. 添加小组件到桌面

- 右键桌面 → 编辑小组件
- 搜索 "DeepSeek 费用"
- 拖拽到桌面或通知中心

## 项目结构

```
DeepSeekCostWidget/
├── project.yml                  # xcodegen 项目配置
├── Shared/                      # 共享代码（App + Widget 共用）
│   ├── Models.swift             # 数据模型
│   ├── AppGroup.swift           # App Groups 共享存储
│   └── DeepSeekAPI.swift        # DeepSeek API 客户端
├── App/                         # 宿主 App
│   ├── DeepSeekCostWidgetApp.swift  # App 入口 + AppDelegate
│   ├── MenuBarManager.swift     # 菜单栏管理
│   ├── DataManager.swift        # 数据刷新协调
│   ├── PopoverView.swift        # 菜单栏弹出面板
│   ├── SettingsView.swift       # 设置窗口
│   └── App.entitlements
└── Widget/                      # Widget Extension
    ├── WidgetBundle.swift       # Widget 入口
    ├── Provider.swift           # TimelineProvider
    ├── WidgetEntryView.swift    # 尺寸路由
    ├── SmallWidgetView.swift    # 小组件
    ├── MediumWidgetView.swift   # 中组件
    ├── LargeWidgetView.swift    # 大组件
    └── Widget.entitlements
```
