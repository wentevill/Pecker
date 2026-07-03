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

**Language: [English](#english) | [中文](README.zh.md)**

---

## English

### What is Pecker

Pecker is a native iOS application designed to help you manage and organize your timeline of important events and activities. The app features a beautiful dark theme interface, AI-powered image recognition capability, and intelligent event detection to keep you focused on what matters most.

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

<p align="center">
<br/><br/>
Made with ❤️ by <a href="https://github.com/wentevill">wentevill</a>
<br/><br/>
</p>
