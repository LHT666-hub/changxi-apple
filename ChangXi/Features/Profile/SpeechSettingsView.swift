import SwiftUI

/// 语音输入设置：控制「云端语音识别（支持方言）」开关与方言选择。
///
/// 偏好写入 ``UserDefaults``（键见 ``SpeechSettingsKeys``），由 ``SpeechController`` 读取：
/// - 关闭（默认）→ 仅用 Apple 本机语音识别，语音不上云；
/// - 开启 → 录音停止后上传后端 `speech/transcribe`，用返回文本填入输入框；失败自动回落本机识别。
///
/// 离线体验模式（`useRemoteAPI == false`，含 UI 测试）下即使开启也不会发起任何网络请求。
struct SpeechSettingsView: View {
    @AppStorage(SpeechSettingsKeys.cloudEnabled) private var cloudEnabled = false
    @AppStorage(SpeechSettingsKeys.dialect) private var dialectRawValue = SpeechDialect.zh.rawValue

    var body: some View {
        Form {
            Section("语音输入") {
                Toggle("使用云端语音识别（支持方言）", isOn: $cloudEnabled)
                    .disabled(!AppConfiguration.supportsExtendedAPI)
                if !AppConfiguration.supportsExtendedAPI {
                    Text("此版本尚未启用玄同云端转写，语音输入使用 Apple 语音识别。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Text(cloudEnabled
                     ? "开启后，你主动录制的语音会上传到常曦后端识别，支持普通话与部分方言；识别失败时自动回落到 Apple 本机识别。"
                     : "关闭时仅使用 Apple 本机语音识别，你的语音不会上传。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if cloudEnabled && AppConfiguration.supportsExtendedAPI {
                Section("识别语言 / 方言") {
                    Picker("方言", selection: $dialectRawValue) {
                        ForEach(SpeechDialect.allCases) { dialect in
                            Text(dialect.label).tag(dialect.rawValue)
                        }
                    }.pickerStyle(.inline)
                    Text("方言识别为可选增强，实际效果取决于后端模型；普通话识别通常最稳定。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !AppConfiguration.useRemoteAPI {
                Section {
                    Label("当前为离线体验模式，云端识别不会发起网络请求。", systemImage: "wifi.slash")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("语音输入")
    }
}
