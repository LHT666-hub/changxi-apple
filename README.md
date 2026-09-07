# 常曦 · ChangXi

原生 SwiftUI 健康陪伴应用，使用 Xcode 26 / iOS 26 SDK 构建，支持 iPhone / iPad，最低兼容 iOS 18。iOS 26 使用系统 Liquid Glass，iOS 18–25 保留 Material 降级样式。

**月相表达过程，数据表达健康。** 月池是实时交互组件，人物、环境与数据各自承担清晰的职责。

## 运行

在 Mac 安装 Xcode，然后：

```sh
brew install xcodegen
xcodegen generate
open ChangXi.xcodeproj
```

选择 `ChangXi` Scheme 和 iPhone / iPad Simulator 运行。真机需选择自己的签名团队。`project.yml` 是工程配置的唯一来源，包含应用、单元测试与 UI 测试三个目标；CI 每次都用 `xcodegen generate` 由它重新生成 `.xcodeproj`，因此**新增源码只要落在 `ChangXi/` 或 `Tests/` 目录下即自动纳入构建**，无需手工登记 pbxproj。

## 当前体验

- 四个主 Tab：首页、健康、服务、我的；iPhone / iPad 始终保留底部导航。
- 全屏文字/语音对话；输入区集中提供附件、文字、麦克风和发送入口。
- 八种月池状态、实时音量水纹、相机与照片选择、本地报告保存。
- 农历日期、月相节律详情和月亮进度；月池人物、水纹与光效使用原生 SwiftUI 动画。
- 健康曲线、测量记录、报告详情、每日计划、用药与服药历史。
- 医生示例消息、咨询草稿、预约意向、活动与课堂。
- 全局“常曦”入口会识别当前表单，确认后可回填血压等结构化内容。
- 记忆确认/编辑/删除、家人服务对象、个人资料、登录注册。
- 本地通知、Dynamic Type、大字模式、Reduce Motion、触觉反馈。
- 原子保存与文件保护、导出、清除数据、错误和空状态。

## 后端对接

应用已接入「玄同」后端的认证、语音转写、报告识别、患者档案、健康记录/测量、事件工作流与照护任务基础设施。全部远程能力遵循**本地优先、上行 best-effort**：离线或后端不可用时降级为本地演示，绝不阻断本机使用。

- 后端地址、路由前缀、各端点契约与错误结构见 [后端对接说明](docs/BACKEND_INTEGRATION.md)。
- 当前 `xuantong/main` 没有 `/api/v1/chat*` 路由；对话严格使用已存在的 `POST /api/events` 与 `patient.message.received` 事件，响应只展示 `workflow.patient_communication`。准确契约与上线前安全缺口见 [常曦 × 玄同对接约定](docs/XUANTONG_INTEGRATION.md)。
- UI 测试以 `--ui-testing` 启动，`AppConfiguration.useRemoteAPI` 强制为 `false`，**所有网络路径直接返回，不发任何真实请求**，保证 CI（无后端）确定性通过。
- 报告中「报告详情 / 分组」等纯离线演示视图渲染内置示例数据，不消费云端结果；真正消费云端识别结果的是导入报告详情视图。

月池动效采用原生 SwiftUI 实现：角色轻呼吸与倾斜使用系统动画，水纹由 Canvas 实时绘制，月相和状态转场使用 SwiftUI 动画 API。项目不依赖 Rive，也不需要 `.riv` 资产。

## 验证

GitHub Actions 使用 macOS-26、XcodeGen 与 iOS Simulator 构建及测试。测试分两层：

- **单元测试（`Tests/Unit`）**：本地状态保存/重载、跨日重置、损坏文件保护、趋势筛选、记忆与用药持久化、报告文件生命周期；网络层的编解码策略、错误归类、请求构造、401 处理、SSE 分帧、健康同步阈值与 payload、患者服务、对话服务。网络测试用自研 `MockURLProtocol`（零第三方依赖）离线拦截，Keychain 相关用例在环境不可用时自动 `XCTSkip`。
- **UI 流程测试（`Tests/UI`）**：主流程导航、记录与服务、大字/横屏布局与截图，全部离线。

共约 53 个用例（单元 + UI）。实际通过情况以 [Actions](https://github.com/LHT666-hub/changxi-apple/actions) 的对应提交结果为准。

```sh
xcodebuild test -project ChangXi.xcodeproj -scheme ChangXi \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

## 结构

- `App`：入口、导航、首次引导、运行配置（`AppConfiguration` / `APIPrefix`）。
- `Core/Design`：统一视觉组件、MoonPool、触感。
- `Core/Models`：状态模型、本地文件、数据迁移。
- `Core/Networking`：`APIClient` / `SSEClient` / `APIError` / `TokenStore` / `AuthService` / `AuthSession` / `ConversationService`，统一 HTTP、鉴权、SSE 与错误契约。
- `Core/Services`：`PatientService` / `HealthRecordService` / `HealthSyncService` / `EventWorkflowService` / `TaskService` / `DocumentService`，桥接后端业务端点。
- `Core/Speech` / `Core/Camera`：系统输入能力与云端语音转写、报告识别。
- `Features`：首页、对话、健康、服务、个人与隐私。
- `Tests`：单元测试与 UI 流程测试。

详细范围和剩余项见 [交付记录](docs/DELIVERY.md)，完整网络层说明见 [后端对接说明](docs/BACKEND_INTEGRATION.md)，当前玄同事件契约见 [常曦 × 玄同对接约定](docs/XUANTONG_INTEGRATION.md)，素材生成提示见 [素材说明](docs/ASSET_PROMPTS.md)。
