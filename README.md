<p align="center">
<b>A smart timeline app with AI-powered image recognition for capturing and organizing your important moments</b>
</p>

<p align=center>
<a href="https://github.com/wentevill/Pecker/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
<a href="https://github.com/wentevill/Pecker"><img src="https://img.shields.io/badge/Language-Swift-orange.svg" alt="Language: Swift"></a>
<a href="https://github.com/wentevill/Pecker/releases"><img src="https://img.shields.io/badge/Platform-iOS-lightgrey.svg" alt="Platform: iOS"></a>
<a href="https://github.com/wentevill/Pecker"><img src="https://img.shields.io/badge/AI-Vision%20Recognition-blueviolet.svg" alt="AI Vision Recognition"></a>
</p>

---

## English

[English](#english) | [中文](#中文)

### What is Pecker

Pecker is a native iOS application designed to help you manage and organize your timeline of important events and activities. The app features a beautiful dark theme interface, AI-powered image recognition capabilities, and leverages Apple's latest technologies including Live Activities and Dynamic Island support to keep you informed about your current priorities.

With Pecker, you can:
- Create and manage a personalized timeline of events
- Intelligently recognize and categorize events from images using AI vision models
- Get real-time notifications about your most important current item
- Experience a polished UI with Live Activity integration
- Organize your schedule with an intuitive interface

### Features

- **Timeline Management** - Create and organize events on an interactive timeline
- **AI Vision Recognition** - Automatically recognize and categorize events from images using advanced machine learning models
- **Live Activities** - Real-time updates on your Lock Screen and Dynamic Island
- **Dark Theme UI** - Beautiful, modern interface with a dark color scheme
- **Smart Notifications** - Stay informed about your current priorities
- **Seamless Integration** - Native iOS 16+ support with latest Apple frameworks
- **Event Detection** - Recognize various event types including meetings, travel, deadlines, interviews, and more

### System Requirements

- **iOS** 16.0+
- **Swift** 5.0+
- **Xcode** 14.0+

### Installation

#### From Source

```bash
git clone https://github.com/wentevill/Pecker.git
cd Pecker
open Pecker.xcodeproj
```

Build and run the project in Xcode on your target iOS device or simulator.

### Architecture

Pecker is built with a modular architecture:

- **PeckerCore** - Core logic and event recognition engine
- **Pecker** - Main app target with UI and features
- **Recognition** - AI-powered image recognition module
- **PeckerLiveActivity** - Live Activity and Dynamic Island support
- **Shared** - Shared utilities and models across targets
- **PeckerTests** - Unit and integration tests

### Development

The project uses Swift Package Manager and Xcode project configuration. See `project.yml` for build settings and `Package.swift` for dependencies.

The Recognition module integrates with vision models to provide intelligent event categorization from images.

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 中文

### Pecker 是什么

Pecker 是一个原生 iOS 应用，旨在帮助您管理和组织您的重要事件和活动的时间线。该应用采用精美的深色主题界面，具备 AI 驱动的图像识别能力，并充分利用 Apple 最新技术，包括 Live Activities 和 Dynamic Island 支持，让您始终了解当前的优先事项。

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
- **无缝集成** - 原生 iOS 16+ 支持，集成最新 Apple 框架
- **事件检测** - 识别多种事件类型，包括会议、出行、截止日期、面试等

### 系统要求

- **iOS** 16.0+
- **Swift** 5.0+
- **Xcode** 14.0+

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

---

<p align="center">
<br/><br/>
Made with ❤️ by <a href="https://github.com/wentevill">wentevill</a>
<br/><br/>
</p>
