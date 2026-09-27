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
            Text("语音输入")
                .font(CXTypography.display)

            if AppConfiguration.supportsExtendedAPI {
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Toggle(isOn: $cloudEnabled) {
                        Text("增强语音识别")
                            .font(CXTypography.section)
                    }

                    if cloudEnabled {
                        Divider().overlay(CX.separator.opacity(0.16))
                        Picker("常用口音", selection: $dialectRawValue) {
                            ForEach(SpeechDialect.allCases) { dialect in
                                Text(dialect.label).tag(dialect.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            } else {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "waveform")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())
                    Text("语音输入")
                        .font(CXTypography.section)
                    Spacer()
                    Text("已开启")
                        .font(CXTypography.meta.weight(.semibold))
                        .foregroundStyle(CX.statusPositive)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            Text("只有你主动使用语音时才会处理录音。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
        }
        .navigationTitle("语音输入")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dialectRawValue = SpeechDialect.fromStoredValue(dialectRawValue).rawValue
        }
    }
}
