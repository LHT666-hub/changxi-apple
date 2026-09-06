# 常曦 · ChangXi

原生 SwiftUI 健康陪伴应用，支持 iPhone / iPad，目标 iOS 18+。

**月相表达过程，数据表达健康。** 月池是实时交互组件，人物、环境与数据各自承担清晰的职责。

## 运行

在 Mac 安装 Xcode，然后：

```sh
brew install xcodegen
xcodegen generate
open ChangXi.xcodeproj
```

选择 `ChangXi` Scheme 和 iPhone / iPad Simulator 运行。真机需选择自己的签名团队。`project.yml` 是工程配置的唯一来源，包含应用与测试目标。

## 当前体验

- 四个主 Tab：首页、健康、服务、我的；全屏文字/语音对话。
- 八种月池状态、实时音量水纹、相机与照片选择、本地报告保存。
- 健康曲线、测量记录、报告详情、每日计划、用药与服药历史。
- 医生示例消息、咨询草稿、预约意向、活动与课堂。
- 记忆确认/编辑/删除、家人服务对象、个人资料、登录注册演示。
- 本地通知、Dynamic Type、大字模式、Reduce Motion、触觉反馈。
- 原子保存与文件保护、导出、清除数据、错误和空状态。

体验版使用明确标注的模拟数据与示例回复。医生咨询和预约只保存本地意向；真实 AI、报告识别、账户服务、医院服务、设备同步尚未接通。

**Rive 分层骨骼与 `.riv` 资产仍未完成。** 当前透明角色使用 SwiftUI 轻呼吸/倾斜，月池由 Canvas 实时绘制，不将这部分误称为 Rive 动画。

## 验证

GitHub Actions 使用 macOS、XcodeGen 与 iOS Simulator 构建及测试。涵盖数据保存/重载、跨日重置、损坏文件保护、测量记录、记忆管理、预约取消、iPhone / iPad 截图和大字/横屏布局。实际通过情况以 [Actions](https://github.com/LHT666-hub/changxi-apple/actions) 的对应提交结果为准。

```sh
xcodebuild test -project ChangXi.xcodeproj -scheme ChangXi \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

## 结构

- `App`：入口、导航、首次引导。
- `Core/Design`：统一视觉组件、MoonPool、触感。
- `Core/Models`：状态模型、本地文件、数据迁移。
- `Core/Speech` / `Core/Camera`：系统输入能力。
- `Core/API`：演示服务与可替换的远程对话接口。
- `Features`：首页、对话、健康、服务、个人与隐私。
- `Tests`：单元测试与 UI 流程测试。

详细范围和剩余项见 [交付记录](docs/DELIVERY.md)，素材生成提示见 [素材说明](docs/ASSET_PROMPTS.md)。
