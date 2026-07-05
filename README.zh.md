<p align="center">
<b>一款智能时间线应用，具备 AI 驱动的图像识别能力，用于捕捉和组织您的重要时刻</b>
</p>

<p align=center>
<a href="https://github.com/wentevill/Pecker/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
<a href="https://github.com/wentevill/Pecker"><img src="https://img.shields.io/badge/Language-Swift-orange.svg" alt="Language: Swift"></a>
<a href="https://github.com/wentevill/Pecker/releases"><img src="https://img.shields.io/badge/Platform-iOS-lightgrey.svg" alt="Platform: iOS"></a>
<a href="https://github.com/wentevill/Pecker"><img src="https://img.shields.io/badge/AI-Vision%20Recognition-blueviolet.svg" alt="AI Vision Recognition"></a>
</p>

---

**语言: [English](README.md) | [中文](#中文)**

---

## 中文

### Pecker 是什么

Pecker 是一个原生 iOS 应用，旨在帮助您管理和组织您的重要事件和活动的时间线。该应用采用精美的深色主题界面，具备 AI 驱动的图像识别能力，并通过智能事件检测技术帮助您专注于最重要的事情。

使用 Pecker，您可以：
- 创建和管理个性化的事件时间线
- 使用 AI 视觉模型智能识别和分类图像中的事件
- 获取有关您当前最重要项目的实时通知
- 体验带有 Live Activity 集成的精美 UI
- 使用直观的界面组织您的日程

### 主要功能

- **时间线管理** - 在交互式时间线上创建和组织事件
- **AI 图像识别** - 使用先进的机器学习模型自动识别和分类图像中的事件
- **Live Activities** - Lock Screen 和 Dynamic Island 上的实时更新
- **深色主题 UI** - 美观、现代的深色主题界面
- **智能通知** - 随时了解您的当前优先事项
- **无缝集成** - 原生 iOS 26+ 支持，集成最新 Apple 框架
- **事件检测** - 识别多种事件类型，包括会议、出行、截止日期、面试等

### 系统要求

- **iOS** 26.0+
- **Swift** 6.0+
- **Xcode** 26.0+

### 安装

#### 从源代码安装

```bash
git clone https://github.com/wentevill/Pecker.git
cd Pecker
open Pecker.xcodeproj
```

在 Xcode 中构建项目并在目标 iOS 设备或模拟器上运行。

### 架构

Pecker 采用模块化架构设计：

- **PeckerCore** - 核心逻辑和事件识别引擎
- **Pecker** - 包含 UI 和功能的主应用 Target
- **Recognition** - AI 驱动的图像识别模块
- **PeckerLiveActivity** - Live Activity 和 Dynamic Island 支持
- **Shared** - 跨 Target 共享的工具函数和数据模型
- **PeckerTests** - 单元测试和集成测试

### 开发

该项目使用 Swift Package Manager 和 Xcode 项目配置。详见 `project.yml` 中的编译设置和 `Package.swift` 中的依赖配置。

Recognition 模块集成了视觉模型，提供从图像中进行智能事件分类的能力。

### 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。
