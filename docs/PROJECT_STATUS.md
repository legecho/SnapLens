# ImageTranslator 项目进度总结

> 更新时间：2026-07-05

---

## 已完成的功能 ✅

### 1. 项目基础架构
- macOS Menu Bar App（SwiftUI）
- 菜单栏图标 + 弹出窗口
- 全局快捷键 ⌃⌘T
- 设置窗口（语言、翻译引擎、外观）

### 2. OCR 文字识别
- Apple Vision 框架集成
- 支持中英文识别
- 文字区域定位（坐标 + 置信度）
- 识别结果正确（测试通过）

### 3. 截图功能 ✅ 已修复
- 使用 ScreenCaptureKit（macOS 26 专用）
- 覆盖层选区 + 全屏截图 + 裁剪
- 坐标转换正确（Scale: image.size / screenFrame.size）
- **截图位置准确**（用户已确认）

### 4. 翻译模块
- TranslationProvider 协议（可扩展）
- AppleTranslator（macOS 26 Translation 框架）
- GoogleTranslator（需 API Key）
- MockTranslator（测试用）
- TranslatorFactory 工厂模式

### 5. 渲染模块
- TranslationRenderer（遮盖原文 + 绘制译文）
- 字号自适应（自动缩小/换行）
- 居中对齐
- 纯色底色遮盖

---

## 当前状态 🔧

### 截图流程（已通）
```
快捷键/按钮 → 覆盖层显示 → 用户框选 → ScreenCaptureKit 截全屏 → 坐标裁剪 → OCR → 翻译 → 渲染 → 显示结果
```

### 待解决
1. **Apple Translation 语言包未下载** — 需要在系统设置中下载中文/英文语言包
2. ~~翻译结果未显示~~ ✅ 已修复（2026-07-05）
3. ~~截图裁剪坐标偏差~~ ✅ 已修复（2026-07-05）— SCStreamConfiguration 显式设置原生分辨率

---

## 最近修复 ✅

### 1. 翻译不成功问题（2026-07-05）
- **问题**：Apple Translation API 语言标识符格式不对
- **修复**：
  - 在 `AppleTranslator` 中添加语言代码映射（"zh-CN" → "zh-Hans" 等）
  - 添加翻译失败时的回退机制（使用 MyMemory 免费 API）
  - 添加更详细的错误信息

### 2. 截图裁剪坐标偏差（2026-07-05）
- **问题**：ScreenCaptureKit 默认输出分辨率（如 1920x1080）与屏幕逻辑尺寸（1280x832）宽高比不一致，导致裁剪位置偏移
- **修复**：
  - 在 `SCStreamConfiguration` 中显式设置 `width = display.width` 和 `height = display.height`，强制以显示器原生像素输出
  - scaleX 和 scaleY 现在完全一致（1.0x1.0），裁剪像素级精确

### 3. 截图后显示结果（2026-07-05）
- **问题**：截图完成后结果窗口没有正确显示
- **修复**：
  - 结果窗口显示在截图位置附近
  - 截图后立即弹出浮动窗口展示完整截图
  - 图片以原始尺寸显示，不缩放不拉伸

---

## 技术栈

| 模块 | 技术 |
|------|------|
| 平台 | macOS 26（Swift/SwiftUI） |
| OCR | Apple Vision 框架 |
| 截图 | ScreenCaptureKit |
| 翻译 | Apple Translation 框架 |
| 渲染 | Core Graphics |
| 快捷键 | Carbon HIToolbox |

---

## 文件结构

```
ImageTranslator/
├── App/
│   ├── AppDelegate.swift          # 菜单栏 + 快捷键 + 设置窗口
│   ├── MenuBarView.swift          # 主界面（翻译流程）
│   └── SettingsView.swift         # 设置界面
├── Modules/
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift    # ScreenCaptureKit 截图
│   │   └── CaptureOverlayView.swift      # 选区覆盖层
│   ├── OCR/
│   │   ├── OCRProvider.swift             # OCR 协议
│   │   └── VisionOCR.swift              # Vision 实现
│   ├── Translation/
│   │   ├── TranslationProvider.swift     # 翻译协议
│   │   ├── AppleTranslator.swift         # macOS 26 翻译
│   │   ├── GoogleTranslator.swift        # Google API
│   │   ├── MockTranslator.swift          # 测试用
│   │   └── TranslatorFactory.swift       # 工厂
│   └── Renderer/
│       └── TranslationRenderer.swift     # 渲染译文
├── Services/
│   ├── ConfigManager.swift        # 配置管理
│   └── HotKeyManager.swift        # 快捷键
└── Utils/
    └── ImageUtils.swift           # 图片工具
```

---

## 下一步

1. 用户下载 Apple 翻译语言包
2. 测试完整翻译流程
3. 优化截图位置精度
4. 添加更多翻译引擎支持
