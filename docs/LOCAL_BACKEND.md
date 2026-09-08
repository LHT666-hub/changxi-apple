# 常曦 × 玄同：已验证的本机连接

> 2026-09-08 分支审查更正：下文记录的是旧 `xuantong/main` 的本机 Mock 验证。最新后端位于 `xuantong/master`（`9f6295b`），已新增认证、对话、文档、语音及健康记录接口和 Novita 模型适配。当前常曦尚未完成与该分支的全链路验证，扩展能力继续关闭。最后只读检查时，本机 `127.0.0.1:8000` 未运行；没有验收可供手机访问的线上地址。不要将下文历史测试当作当前线上可用证明。

基线：常曦远端 `7095806`，玄同 `main` `c05543a`。本机原有未完成 UI 修改保存在 `codex/local-ui-checkpoint-20260908`，本次以远端交互实现为准。

## 仓库与服务不是同一个地址

GitHub 保存源码，不执行玄同的 Python 服务。模拟器可以访问同一台 Mac 的 `http://127.0.0.1:8000`。真机不能使用这个地址，需要可访问的服务器。当前后端没有用户鉴权，不应直接开放公网；生产部署、身份授权与真实模型配置仍需完成。

## 本机启动

在玄同仓库目录执行（需要 uv）：

```sh
uv venv --python 3.12
uv pip install -e '.[dev]'
LLM_PROVIDER=mock RAG_USE_RERANKER=false .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

在常曦「我的 → 玄同连接」输入根地址，点击「检查并使用这个地址」。页面会区分 Mock 测试模型与真实模型提供方。命令行 `-apiBaseURL`、`XUANTONG_BASE_URL` 优先于 App 保存的地址，联调时不要同时设置冲突地址。

需要验证请求确实从 App 发出时，先启动玄同，再运行：

```sh
XUANTONG_TEST_BASE_URL=http://127.0.0.1:8000 \
  xcodebuild test -project ChangXi.xcodeproj -scheme ChangXi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ChangXiUITests/FlowTests/testLiveXuantongConversationWhenRequested
```

测试会先探测玄同：服务在线就用 `--integration-testing` 准备无个人资料的示例状态并走真实网络；服务离线则跳过。因此普通 CI 不依赖本机后端。

真实 AI 需要在后端本机 `.env` 私下配置 `LLM_PROVIDER=qwen`、`LLM_API_KEY` 与服务地址。不要将密钥放进 iOS App、聊天或 Git。当前验证使用独立 SQLite 测试库和 MockProvider，不代表真实 Qwen 调用已完成。

## 已验证链路

- `GET /api/health/detail`：服务健康、模型提供方。
- `POST /api/events`：`patient.message.received`，读取 `workflow.patient_communication`。
- `POST /api/events`：`blood_pressure.recorded`；`payload.measurements` 含 `type/value/secondary_value/unit/measured_at`，与工作流临床上下文读取方式一致。
- `GET /api/tasks?patient_id=...` → `POST /api/tasks/{id}/complete` → 患者 timeline，使用合成测试数据验证成功。
- App 的实际 `XuantongEventConversationService` Swift 源码连接运行中的玄同成功。

健康数值上行现在直接使用事件接口，不再先请求尚未实现的健康记录创建接口。事件 ID 保存在本地，已成功上行的记录不会再次创建事件。事件接口尚未支持幂等键，网络超时后重试仍可能创建重复事件。

## 旧 main 基线缺失的能力（不代表最新 master）

旧玄同 `main` 没有认证、`/api/v1/documents*`、独立语音转写、健康记录写入/测量历史接口。最新 `master` 已补充相关路由，但 App 仍关闭尚未联调的扩展请求，照片与档案仍在本机，语音使用 Apple 转写。健康数据上传为事件归档，不代表跨设备恢复已经验收。

PDF / UTF-8 文本选择后提取至多 12000 字，点击发送才提交。扫描 PDF 无文字层时明确提示，不伪装成成功识别。连接失败保留重试状态，不把本地示例回复冒充为云端 AI。
