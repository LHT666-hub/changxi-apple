# 常曦原生前端交付记录

本次范围来自九张视觉参考图与「浴月系统」产品规范，并在后续三轮中完成后端接线。目标 iOS / iPadOS 18+，SwiftUI 原生应用。

## 已实现

- 首页 / 健康 / 服务 / 我的四个主 Tab；沉浸式对话采用全屏呈现。
- 首次引导、体验与隐私说明、称呼编辑、访客模式。
- 首页最多三项今日信息，与健康记录、计划、医生示例消息联动。
- 月池八状态：idle、listening、thinking、responding、success、notification、doctorReply、quietAlert。Canvas 实时波纹、思考收拢与月相、回应中心亮起、成功光环、单/双光点、静默停止。
- AVAudioEngine RMS 音量驱动波纹；Apple Speech 本机转写；停止、退后台、离开页面释放麦克风；权限拒绝与错误恢复。
- 文字对话、回复加载/取消/重试、持久历史、清空历史、报告照片入口。
- PhotosPicker 与真实相机、权限拒绝、设备不支持、图片加载失败、预览与文字说明。
- 血压/血糖/体重详情、记录校验、日期与备注、删除确认、7/30/90天图表筛选。
- 报告列表、详情、逐项数值/单位/参考区间/文字标记。
- 今日计划、完成/撤销、睡前日记、跨日重置、用药管理入口。
- 医生详情、消息、咨询草稿、六类服务、预约意向与取消、课堂、活动。
- 记忆确认、修改、分类、删除、暂停确认；服务对象切换；健康档案。
- 本地通知权限与每日提醒；大字模式、系统 Dynamic Type、Reduce Motion、可选 Core Haptics。
- JSON 原子写入、系统完整文件保护、损坏文件保留与错误提示、导出、重置。

## 后端接线（三轮）

已接入「玄同」后端，契约与端点映射见 [后端对接说明](BACKEND_INTEGRATION.md)。

- **网络底座 + 认证 + 对话**：`Core/Networking`（`APIClient` / `SSEClient` / `APIError` / `TokenStore` / `AuthService` / `AuthSession` / `ConversationService`），真实注册/登录（表单编码）、JWT Bearer 鉴权、401 会话过期通知；非流式与 POST-SSE 流式对话；`RootView` / `DemoAuthView` / `ChatView` 接线。
- **语音 + 报告识别**：云端语音转写（`SpeechTranscriptionService`，multipart 上传）、报告识别（`DocumentService` + `CloudDocumentsView`）、语音设置页；识别结果写入导入报告并持久化。
- **健康数据同步 + 工作流进度**：患者档案、健康记录/测量上行与下行合并、异常读数触发会诊工作流（`EventWorkflowService`）、照护任务（`TaskService`）、工作流实时进度页（`WorkflowProgressView`）。

全部远程能力遵循**本地优先、上行 best-effort、离线零请求**：`AppConfiguration.useRemoteAPI == false`（含 `--ui-testing`）时每个网络方法首行 `guard` 直接返回。

## 尚未完成 / 不得误报为完成

- **Rive 角色骨骼与 .riv：未完成。** 目前仅有生成的透明角色素材与 SwiftUI 整体轻呼吸/倾斜；不是分层骨骼动画，也没有宣称这是 Rive。
- **后端健康记录 / 测量没有 DELETE 端点**：本地删除读数只移除本机记录，云端副本保留为历史归档（`HealthSyncService.noteLocalDeletionNotSynced` 仅语义占位，不发请求）。
- 医生通信、挂号、远程推送、HealthKit/蓝牙设备同步仍未接通；相应页面说明当前状态。
- 登录/注册已接通后端认证，但**验证码/短信通道**仍以后端实现为准；不宣称已接入真实运营商短信。
- `PatientContext.bindProfileIfNeeded` 硬编码 `APIClient.shared` 与 Keychain 标记，单元测试无法注入，仅测其依赖的建档标记机制；编排层的端到端建档需在模拟器 + 真实后端手动验证。
- Keychain（`TokenStore`）在部分无头 CI 环境不可用；相关单元测试以 `XCTSkip` 守卫，**生产 Keychain 行为需在模拟器手动验证**。
- 无实体 iPhone/iPad，触觉强度、麦克风、相机、系统权限和所有无障碍组合需真机验收。
- 视觉目标为参考图气质与原生布局，尚未宣称逐像素复刻。

## 医学与交互语义

月相表达过程，数据表达健康。月相不用于判断健康好坏。示例报告明确标注数据来源属性；本地对话不做诊断或用药调整；服务意向保存不会发送消息。异常读数触发的是「玄同会诊工作流」进度展示，非实时医疗诊断。

## 素材

采用内置 imagegen，根据用户角色参考图生成两个独立素材：

- `ChangXi/Resources/Assets.xcassets/MoonGarden.imageset/garden.png`：月白拱窗、雾蓝山湖、小月亮、留白；删除人物、水纹、界面和文字。
- `ChangXi/Resources/Assets.xcassets/ChangXiCharacter.imageset/character.png`：保留深蓝长发、月牙发饰、白蓝汉服与触水姿势，透明背景独立人物。

生成提示要求保留原角色身份和2.5D质感，背景不含人物、文字或界面。水纹由代码绘制，不烘焙进图像。

## 构建与验证

`project.yml` 是完整工程配置，包含 App、单元测试与 UI 测试。GitHub Actions 使用 macOS-15、XcodeGen 和 iOS Simulator，每次由 `project.yml` 重新生成工程后构建、测试并导出附件。运行结果见仓库 Actions。

Mac 本地：

```sh
brew install xcodegen
xcodegen generate
open ChangXi.xcodeproj
```

选择 iPhone 或 iPad Simulator 后运行。真机需选择自己的签名团队。

关键检查：数据重启保留、跨日计划重置、损坏存储不覆盖、趋势区间筛选、记忆删除保留、网络层编解码/错误/SSE、健康同步阈值、主流程导航与对话，以及截图附件。仅 macOS CI 通过后才能标注“构建通过”。
