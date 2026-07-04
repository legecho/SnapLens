# ImageTranslator 设计文档

> macOS 原生图片翻译覆盖工具，框选屏幕区域，OCR 识别 → 翻译 → 译文原位覆盖显示。

---

## 1. 功能概述

对屏幕截图或图片中的外文内容进行翻译，将译文**直接覆盖显示在原文所在的对应位置上**，实现"原位替换"的视觉效果。

核心流程：**OCR 定位 → 纯色遮盖原文 → 原位写入译文 → 字号自适应不溢出**

---

## 2. 技术选型

| 模块 | 方案 |
|------|------|
| 平台 | macOS（Swift/SwiftUI），后续可跨平台 |
| UI 框架 | SwiftUI + AppKit |
| OCR | Apple Vision 框架（可扩展） |
| 翻译 | Google Translate API（可扩展） |
| 图片处理 | Core Graphics / Core Image |
| 打包 | Xcode，支持 DMG 分发 |

---

## 3. 架构设计

```
┌─────────────────────────────────────────────┐
│  Menu Bar App (SwiftUI)                      │
├─────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────────────┐  │
│  │ Screen       │  │ Translation Overlay  │  │
│  │ Capture      │  │ (透明窗口覆盖屏幕)    │  │
│  │ (框选区域)   │  │                      │  │
│  └──────┬──────┘  └──────────┬───────────┘  │
│         │                    │               │
│  ┌──────▼──────┐  ┌──────────▼───────────┐  │
│  │ OCR Engine  │  │ Translation Engine   │  │
│  │ (Vision)    │  │ (Google/本地AI/API)  │  │
│  └──────┬──────┘  └──────────┬───────────┘  │
│         │                    │               │
│  ┌──────▼────────────────────▼───────────┐  │
│  │ Renderer                              │  │
│  │ 纯色遮盖原文 → 计算字号 → 绘制译文     │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### 3.1 模块职责

| 模块 | 职责 | 可扩展性 |
|------|------|----------|
| Screen Capture | 截图框选，获取屏幕区域图像 | 后续扩展为完整截图工具 |
| OCR Engine | 文字检测 + 识别，返回文字块坐标和文本 | 切换 PaddleOCR / EasyOCR |
| Translation Engine | 文本翻译，支持多语言 | 切换 DeepL / 本地 AI |
| Renderer | 遮盖原文 + 绘制译文 + 字号自适应 | — |
| Config Manager | 配置项管理 | — |

### 3.2 协议抽象

```swift
// OCR 抽象层
protocol OCRProvider {
    func recognize(image: NSImage) async throws -> [TextBlock]
}

struct TextBlock {
    let text: String
    let rect: CGRect      // 文字区域坐标（相对于图片）
    let confidence: Float
}

// 翻译抽象层
protocol TranslationProvider {
    func translate(
        _ text: String,
        from sourceLang: String,
        to targetLang: String
    ) async throws -> String
}
```

---

## 4. 核心流程

### 4.1 用户交互流程

1. 用户点击菜单栏图标 / 快捷键 `⌃⌘T`
2. 屏幕变暗，进入框选模式
3. 用户拖拽框选目标区域
4. 截取框选区域图像
5. OCR 识别文字块（并行处理多个文字块）
6. 自动翻译所有文字块（或用户手动触发）
7. Renderer 合成译文覆盖图
8. 透明窗口显示在原文位置
9. 点击其他区域 / `ESC` 退出

### 4.2 渲染算法

```
输入: 原图 + [TextBlock] + [翻译结果]

对每个 TextBlock:
  1. 用纯色（白色/浅灰）填充 rect 区域
  2. 计算初始字号: fontSize = rect.height × 0.65
  3. 测量译文宽度（用当前字号）
  4. 如果译文宽度 > rect.width:
     缩小比例 = rect.width / 译文宽度
     fontSize = fontSize × 缩小比例
  5. 如果译文仍然过长（单行放不下）:
     自动换行，按行绘制
  6. 居中绘制译文到 rect 中心
```

### 4.3 多文字块翻译

- OCR 返回多个文字块时，按阅读顺序排序（从上到下，从左到右）
- 批量翻译请求（合并为一次 API 调用，减少延迟）
- 每个文字块独立渲染，互不影响

---

## 5. UI 设计

### 5.1 菜单栏

- 常驻菜单栏图标（相机/翻译图标）
- 点击展开：
  - 开始翻译（⌘T）
  - 设置
  - 退出

### 5.2 框选模式

- 屏幕截图作为背景
- 半透明黑色覆盖层
- 框选区域高亮显示
- 十字光标 + 坐标提示

### 5.3 翻译结果覆盖层

- 无边框透明窗口
- 精确覆盖在原文位置
- 支持拖拽移动
- 点击关闭

---

## 6. 配置项

| 配置 | 默认值 | 类型 | 说明 |
|------|--------|------|------|
| targetLanguage | zh-CN | String | 目标翻译语言 |
| ocrEngine | vision | Enum | OCR 引擎选择 |
| translationEngine | google | Enum | 翻译引擎选择 |
| hotKey | ⌃⌘T | HotKey | 触发快捷键 |
| overlayColor | #FFFFFF | Color | 遮盖底色 |
| autoTranslate | true | Bool | 框选后自动翻译 |
| opacity | 0.95 | Double | 译文区域不透明度 |

---

## 7. 文件结构

```
ImageTranslator/
├── App/
│   ├── AppDelegate.swift
│   └── MenuBarView.swift
├── Modules/
│   ├── Capture/
│   │   ├── ScreenCapture.swift
│   │   └── CaptureOverlay.swift
│   ├── OCR/
│   │   ├── OCRProvider.swift
│   │   └── VisionOCR.swift
│   ├── Translation/
│   │   ├── TranslationProvider.swift
│   │   ├── GoogleTranslator.swift
│   │   └── LocalAITranslator.swift
│   └── Renderer/
│       └── TranslationRenderer.swift
├── Services/
│   ├── ConfigManager.swift
│   └── HotKeyManager.swift
├── Utils/
│   └── ImageUtils.swift
├── Resources/
│   ├── Assets.xcassets
│   └── Info.plist
└── ImageTranslator.xcodeproj
```

---

## 8. 扩展点设计

### 8.1 截图功能扩展

当前 Screen Capture 仅用于框选翻译区域，后续可扩展为完整截图工具：
- 全屏截图
- 窗口截图
- 滚动截图
- 截图标注/编辑

架构上 Screen Capture 模块独立，通过协议解耦，扩展不影响翻译功能。

### 8.2 翻译引擎扩展

新增翻译引擎只需：
1. 实现 `TranslationProvider` 协议
2. 在 ConfigManager 中注册
3. UI 设置中添加选项

### 8.3 OCR 引擎扩展

新增 OCR 引擎只需：
1. 实现 `OCRProvider` 协议
2. 在 ConfigManager 中注册

---

## 9. 非功能需求

| 项目 | 要求 |
|------|------|
| 性能 | OCR + 翻译总延迟 < 3 秒（取决于 API） |
| 内存 | 单次处理图片内存占用 < 200MB |
| 包体 | < 50MB（不含 OCR 模型） |
| 系统要求 | macOS 13.0+ |

---

## 10. 后续迭代

- **v1.1**：截图功能扩展（全屏/窗口/滚动）
- **v1.2**：截图标注/编辑
- **v1.3**：历史记录
- **v2.0**：跨平台（Tauri/Flutter）

---

## 11. 不在范围内

- 不需要还原原始背景纹理或颜色
- 不需要匹配原文字体样式
- 不需要支持实时视频流翻译
- 不需要 OCR 置信度过滤（所有识别结果都显示）
