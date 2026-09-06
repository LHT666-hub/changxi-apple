# 常曦 iOS ↔ 玄同后端 对接说明

本文件描述常曦 iOS 客户端与「玄同」后端的对接契约，供联调、回归与后续维护参考。后端源码为只读参考，不在本仓库。

## 1. 运行配置

| 项 | 位置 | 说明 |
| --- | --- | --- |
| 远程开关 | `AppConfiguration.useRemoteAPI` | `--ui-testing` 下强制 `false`；其余默认 `true`。为 `false` 时所有网络方法首行 `guard` 直接返回，离线零请求。 |
| 后端地址 | `AppConfiguration.apiBaseURL` | 优先级：启动参数 `-apiBaseURL <url>` > `Info.plist` 的 `CX_API_BASE_URL` > 编译期兜底（模拟器 `http://127.0.0.1:8000`）。 |
| 明文 HTTP 策略 | `AppConfiguration.allowsInsecureHTTP(_:)` | DEBUG 放行；Release 仅对本地回环放行，其余强制 HTTPS。`APIClient` 在构造请求时校验，非法则抛 `APIError.network`。 |
| 超时 | `AppConfiguration.requestTimeout` | 统一 60s（对话生成较慢）。 |

## 2. 路由前缀

后端路由前缀不统一，客户端用 `APIPrefix` 枚举选择：

| 前缀 | 常量 | 覆盖 |
| --- | --- | --- |
| `/api/auth` | `.auth` | 注册、登录、当前用户 |
| `/api/v1` | `.v1` | 对话、流式对话、多模态、文档识别、语音转写、SSE 事件流 |
| `/api` | `.legacy` | 患者、健康记录、测量、事件（工作流）、任务、时间线 |

## 3. 认证

- 端点：`POST /api/auth/register`（JSON）、`POST /api/auth/login`（表单）、`GET /api/auth/me`（当前用户）。登录端点为 OAuth2 表单，**必须**用 `application/x-www-form-urlencoded`（`APIClient.postForm`），发 JSON 会被判 422。
- 令牌存储：`TokenStore`（Keychain，`kSecClassGenericPassword`，`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`）。默认 `account = access_token`。
- 令牌注入：`APIClient` 每次请求自动加 `Authorization: Bearer <token>`。
- 会话过期：收到 **401** 时清空 token 并发出 `Notification.Name.cxSessionExpired`；后端**无 refresh 机制**，上层据此跳转登录。

## 4. 对话

| 能力 | 方法 | 端点 |
| --- | --- | --- |
| 非流式问答 | `RemoteConversationService.send` | `POST /api/v1/chat` |
| 流式问答（POST-SSE） | `RemoteConversationService.streamReply` | `POST /api/v1/chat/stream` |
| 创建会话 | `createSession` | `POST /api/v1/chat/sessions` |
| 列出会话 | `listSessions` | `GET /api/v1/chat/sessions?patient_id=` |
| 列出消息 | `listMessages` | `GET /api/v1/chat/sessions/{id}/messages?limit=` |
| 追加消息 | `appendMessage` | `POST /api/v1/chat/sessions/{id}/messages` |
| 删除会话 | `deleteSession` | `DELETE /api/v1/chat/sessions/{id}` |

请求体 `ChatRequest`：`message` / `patient_id` / `session_id` / `context`（`{role, content}` 数组）。响应 `ChatReply`：`reply` / `agent_role`（固定 `family_doctor`）/ `session_id` / `metadata`。

### 4.1 POST-SSE 事件流

后端 `/chat/stream` 是 **POST** 方式的 `text/event-stream`，浏览器 `EventSource` 只支持 GET，故客户端用 `URLSession.bytes(for:)` 逐行分帧（`SSEClient`）：

- 以空行分隔报文块；块内 `event:` 取事件名（缺省 `message`），`data:` 取内容（多行按换行拼接）。
- 以冒号开头的行是心跳/注释，直接丢弃。
- 收到 `event: complete` 或 `event: timeout` 后主动关闭连接。

事件语义（`streamReply` 处理）：

| 事件 | 载荷 | 处理 |
| --- | --- | --- |
| `message` | `{chunk, done}` | 累积文本并回调打字机增量 |
| `guard` | `{reply}` | OutputGuard 改写/阻断的最终全文 |
| `complete` | `{reply, agent_role?, session_id?, metadata?}` | 最终可信结果，**优先级最高** |
| `error` | `{message}` | 无最终结果时抛 `APIError.http` |
| `timeout` | — | 无错误信息时兜底为「回复超时」 |

最终结果优先级：`complete` > `guard 全文` > `累积文本`；均为空则抛错，上层降级到 `DemoConversationService`。

### 4.2 metadata 安全护栏

`ChatMetadata`：`guard`（`emergency` / `block`）、`reason`、`degraded`。`isGuarded` / `isEmergency` / `badge`（紧急提示 / 内容已拦截 / 简化回复）供 UI 醒目标注。

## 5. 多模态（语音 / 文档）

`APIClient.postMultipart` 构造 `multipart/form-data`，文件字段名约定为 `file`。

| 能力 | 服务方法 | 端点 |
| --- | --- | --- |
| 云端语音转写 | `SpeechTranscriptionService.transcribe` | `POST /api/v1/speech/transcribe`（multipart，文件字段 `file`，含方言/语言字段） |
| 文档识别（分析） | `DocumentService.analyze` | `POST /api/v1/documents/analyze`（multipart） |
| 文档上传入库 | `DocumentService.uploadDocument` | `POST /api/v1/documents`（multipart，字段 `patient_id` / `doc_type`） |
| 列出文档 | `DocumentService.listDocuments` | `GET /api/v1/documents?patient_id=&page=&size=` |
| 预签名下载 | `DocumentService.presignURL` | `GET /api/v1/documents/{id}/presign` |
| 删除文档 | `DocumentService.deleteDocument` | `DELETE /api/v1/documents/{id}` |

语音转写默认关闭，需用户在「语音输入」设置页开启云端识别；本机识别始终走 Apple Speech。报告识别结果写入导入报告（`analysisText` / `findings` / `bpReading` / `documentID`）并持久化。

## 6. 患者与健康数据

全部走 `.legacy` 前缀（`/api`）。

| 能力 | 方法 | 端点 |
| --- | --- | --- |
| 建档 | `PatientService.createPatient` | `POST /api/patients` |
| 查询/更新/删除 | `getPatient` / `updatePatient` / `deletePatient` | `GET|PUT|DELETE /api/patients/{id}` |
| 时间线 | `getTimeline` | `GET /api/patients/{id}/timeline` |
| 测量历史 | `getMeasurements` | `GET /api/patients/{id}/measurements` |
| 健康记录 | `HealthRecordService.createRecord` / `listRecords` / `getRecord` | `POST|GET /api/health-records*` |
| 追加测量 | `appendMeasurement` | `POST /api/health-records/{id}/measurements` |
| 触发会诊工作流 | `EventWorkflowService.reportEvent` | `POST /api/events`（`.legacy`，阻塞至完成，返回 workflow） |
| 工作流状态/详情 | `getEventStatus` / `getEvent` | `GET /api/events/{id}/status` · `GET /api/events/{id}`（`.legacy`） |
| 工作流实时进度 | `EventWorkflowService` SSE | `/api/v1/events/{id}/stream`（**注意前缀是 `.v1`**，与上报的 `.legacy` 不同） |
| 照护任务 | `TaskService.listTasks` / `getTask` / `completeTask` | `GET /api/tasks` · `GET /api/tasks/{id}` · `POST /api/tasks/{id}/complete`（`.legacy`） |

字段映射（`HealthMetricMapping`）：

| MetricKind | measurement_type | unit | event_type / record_type |
| --- | --- | --- | --- |
| 血压 | `blood_pressure` | `mmHg`（value=收缩压, secondary=舒张压） | `bp_reading` |
| 血糖 | `blood_glucose` | `mmol/L` | `glucose_reading` |
| 体重 | `weight` | `kg` | `weight_reading` |

### 6.1 同步语义

- **上行**（`uploadReading`）：建健康记录 → 追加测量 → 若异常再触发工作流。全程 best-effort，任一步失败标记 `SyncState.failed`，**不抛出、不影响本地**。
- **异常阈值**（`triggersWorkflow`）：血压 收缩压≥140 或 舒张压≥90；血糖 ≥7.0 或 <3.9；体重不触发。
- **下行**（`pullRemote`）：进入健康页拉取云端测量并合并去重，判重键 = `kind + value(±0.01) + secondary(±0.01) + date(±60s)`，本地优先。
- **删除缺口**：后端健康记录/测量**无 DELETE 端点**，本地删除无法同步；云端副本保留为历史归档。
- **归档**（`archive`）：计划/用药/记忆单向归档为 health-record（`record_type` 分别 `daily_plan` / `medication` / `memory`）。

### 6.2 单一患者标识

全 app 统一使用 `PatientContext.effectiveID(_:)` = `登录用户 ID ?? RemoteConversationService.localPatientId`（Keychain `account = patient_id` 缓存的稳定 UUID）。**不引入第二套 patientID**。后端各子资源端点会 `normalize_patient_id` 把该稳定标识规范化为确定性 UUID，且无需 patients 表存在对应行即可写入/查询。`bindProfileIfNeeded` 仅一次性 best-effort 补建档案（Keychain 标记 `patient_profile_bound`），绝不覆盖标识，失败不阻断本地。

## 7. 错误契约

后端存在两种错误 JSON，`APIError.parse` 都能容错：

- **格式 A（FastAPI HTTPException）**：`{"detail": "..."}`，`detail` 也可能是校验错误数组 `[{"loc","msg","type"}]`。
- **格式 B（XuantongError / 全局校验 / 500）**：`{"error": {"code","message","detail"|"details"}}`。

状态码归类：401 → `.unauthorized`；422 → `.validation([String])`；503 → `.serverBusy`；其余 → `.http(status, message)`；无 HTTP 响应 → `.network`；解码失败 → `.decoding`。面向用户统一用 `userFacingMessage`，`X-Request-ID` 前 8 位拼进错误描述便于联调。

## 8. 测试策略

- **零第三方依赖**：网络测试用自研 `MockURLProtocol`（`Tests/Unit/MockURLProtocol.swift`）经 `URLSessionConfiguration.protocolClasses` 注入，离线拦截全部请求；`APIClient.makeMock()` 用 `https://unit.test` 绕过明文校验且被 mock 拦截，不发生真实 DNS/TLS。
- **CI 无后端**：任何真实网络请求都会超时，故网络用例全部走 mock；UI 测试 `--ui-testing` 强制离线。
- **CI 串行**：`-parallel-testing-enabled NO`，`MockURLProtocol` 用静态 handler + `NSLock`，每用例 `setUp/tearDown` 调 `reset()`。
- **请求体断言**：POST body 可能被 URLSession 移入 `httpBodyStream`，故只断言 method/path/headers，body 编码用纯静态方法（`urlEncodedBody` / `multipartBody` / `makeEncoder`）单独测。
- **Keychain**：`TokenStore` 用原生 `SecItem*`，在部分无头 CI 环境不可用；相关用例以 `XCTSkip` 守卫（写入-读回探测失败即 skip），**绝不 CI 红**；生产 Keychain 行为需在模拟器手动验证。
- **SSE 泛型**：`SSEClient.stream<B: Encodable>(body:)` 省略 body 时 `B` 不可推断，测试必须显式传具体请求体。
