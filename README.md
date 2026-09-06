# 常曦 · ChangXi Apple Native

常曦的 Apple 原生客户端。目标是 iPhone + iPad Universal App，使用 SwiftUI 原生实现，而不是 WebView 包装网页。

## 定位

- **产品与业务来源**：现有业务后端的 API、身份、服务流程、资料与数据库能力。
- **AI 能力来源**：玄同（Xuantong）的 Agent / RAG / Safety 能力逐步接入。
- **客户端品牌**：统一使用 **常曦 / ChangXi**。

## 第一阶段

- SwiftUI 原生首页
- 常曦对话页
- 原生语音入口（待接 `/api/v1/speech/transcribe`）
- 原生拍照入口（待接 `/api/v1/documents/analyze`）
- iPhone / iPad Universal
- 原生材质、SF Symbols、触感与动画体系逐步加入

## Xcode

项目目标：iOS / iPadOS 18+

Bundle Identifier 暂定：`com.lht.changxi`

开发期 API 地址在 `Core/API/APIClient.swift` 中配置。真机调试时不要使用 `127.0.0.1` 指向 Mac 服务，应改为 Mac 的局域网 IP 或正式 HTTPS API 地址。
