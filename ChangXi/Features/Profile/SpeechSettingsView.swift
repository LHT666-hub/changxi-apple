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
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("语音输入")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("说话，也应该知道声音去了哪里")
                    .font(CXTypography.display)

                Text("默认优先使用本机识别；只有你主动开启云端识别后，录音才会上传用于转写。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "识别方式")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Toggle(isOn: $cloudEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("云端语音识别")
                            .font(CXTypography.section)
                        Text("支持方言与地区口音；不可用时会回落本机识别")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }
                }

                HStack(alignment: .top, spacing: CXSpacing.sm) {
                    Image(systemName: cloudEnabled ? "cloud.fill" : "iphone")
                        .foregroundStyle(CX.actionPrimary)
                    Text(speechPrivacyDescription)
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                        .lineSpacing(4)
                    Spacer(minLength: 0)
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            if cloudEnabled {
                SectionEyebrow(title: "方言与地区口音")
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Picker("方言", selection: $dialectRawValue) {
                        ForEach(SpeechDialect.allCases) { dialect in
                            Text(dialect.label).tag(dialect.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("方言识别是可选增强，实际效果取决于识别模型和录音环境。")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                        .lineSpacing(4)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            if !AppConfiguration.supportsExtendedAPI {
                CXEmptyState(
                    title: "云端转写尚未启用",
                    message: "你的方言偏好会保留；在云端能力接入前，语音仍只使用 Apple 本机识别。",
                    icon: "icloud.slash"
                )
            } else if !AppConfiguration.useRemoteAPI {
                HStack(alignment: .top, spacing: CXSpacing.sm) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(CX.statusWarning)
                    Text("当前为离线体验模式，云端识别不会发起网络请求。")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                    Spacer(minLength: 0)
                }
                .padding(CXSpacing.md)
                .background(
                    CX.statusWarning.opacity(0.05),
                    in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                )
            }
        }
        .navigationTitle("语音输入")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dialectRawValue = SpeechDialect.fromStoredValue(dialectRawValue).rawValue
        }
    }

    private var speechPrivacyDescription: String {
        guard cloudEnabled else {
            return "关闭时只使用 Apple 本机语音识别，语音不会上传。"
        }
        guard AppConfiguration.supportsExtendedAPI else {
            return "方言偏好已保存。云端能力接入前，录音仍只使用本机识别。"
        }
        return "开启后，你主动录制的语音会上传到常曦后端用于转写；失败时自动回落本机识别。"
    }
}
