# 常曦 × 玄同对接约定

对接基线：`LHT666-hub/xuantong` `main` @ `c05543a`。

## 对话入口

常曦不调用独立 chat 路由，而是将患者输入作为事件提交到玄同工作流：

```http
POST /api/events
Content-Type: application/json
```

```json
{
  "patient_id": "<stable local UUID>",
  "event_type": "patient.message.received",
  "channel": "changxi",
  "source": "changxi-ios",
  "payload": { "message": "患者输入" },
  "metadata": {
    "client": "ios",
    "contract_version": "xuantong-events-v1"
  }
}
```

客户端显示 `workflow.patient_communication`，不直接显示 Agent 的中间分析。`workflow.clinical_risk` 为 `yellow` / `red` 时，月池分别进入提醒/静默警示态；`workflow.status == "failed"` 或回复缺失时进入可重试错误态。

## 环境配置

在 Xcode Scheme 中设置 `XUANTONG_BASE_URL`。未设置时使用明确标注的本地演示回复。

- 本机开发：`http://127.0.0.1:8000`
- 真机或发布：必须使用 HTTPS，且不能使用 App 内置密钥

## 后续契约

- 血压：`blood_pressure.recorded`，payload 的 `measurements` 中使用 `type: blood_pressure`、`value` 传收缩压、`secondary_value` 传舒张压，并带 `unit` / `measured_at`。
- 血糖：`blood_glucose.recorded`，同样通过 payload 的 `measurements` 传 `type: blood_glucose`、`value`、`unit` 和 `measured_at`。
- 报告：`report.uploaded`，图像必须走后端授权上传，不把 base64 长期留在本地日志。
- 任务：通过 `GET /api/tasks?patient_id=...` 拉取，完成操作对应 `POST /api/tasks/{id}/complete`。
- 生产上线前必须补齐用户身份绑定、授权令牌、端到端审计和 API 版本化。当前玄同路由没有用户鉴权，不得直接暴露到公网。
