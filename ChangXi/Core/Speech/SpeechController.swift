import AVFoundation
import Foundation
import Observation
import Speech

@MainActor @Observable
final class SpeechController {
    var isRecording = false
    var isStarting = false
    var level = 0.0
    var transcript = ""
    var error: String?
    /// 云端增强转写进行中（stop 后上传音频期间为 true）。
    var isTranscribing = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var hasTap = false
    private var sessionID = UUID()
    /// 本次录音的 PCM 采集器：stop 时封装为 WAV 供云端转写上传。
    private var accumulator: PCMAccumulator?

    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        let id = UUID()
        sessionID = id
        error = nil
        defer { if sessionID == id { isStarting = false } }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard sessionID == id else { return }
        guard micAllowed else { error = "麦克风权限未开启，可改用键盘输入，或到系统设置中开启。"; return }
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        guard sessionID == id else { return }
        guard status == .authorized else { error = "语音识别权限未开启，可继续使用键盘输入。"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else { error = "语音识别暂不可用，请检查网络或使用键盘。"; return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            self.request = request
            transcript = ""
            // 无论是否启用云端识别都采集 PCM：启用时用于上传，未启用时在 stop 处直接忽略（零网络成本）。
            let accumulator = PCMAccumulator()
            self.accumulator = accumulator
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw URLError(.cannotLoadFromNetwork) }
            // tap 闭包运行在音频线程：`accumulator`（@unchecked Sendable）与 `id`（UUID）按值捕获，
            // 不经 `self` 访问隔离属性；音量更新仍通过 Task 跳回 MainActor。
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                accumulator.append(buffer)
                guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                let count = Int(buffer.frameLength)
                var energy: Float = 0
                for index in 0..<count { energy += samples[index] * samples[index] }
                let rms = sqrt(energy / Float(count))
                let normalized = min(max((20 * log10(max(rms, 0.00001)) + 55) / 45, 0), 1)
                Task { @MainActor in guard let self, self.sessionID == id else { return }; self.level = self.level * 0.35 + Double(normalized) * 0.65 }
            }
            hasTap = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                Task { @MainActor in
                    guard let self, self.sessionID == id else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if failure != nil { self.stop(); self.error = "语音识别已停止。已识别的文字会保留，可修改后发送。" }
                    else if result?.isFinal == true { self.stop() }
                }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            stop()
            self.error = "无法启动麦克风，请检查设备或改用键盘输入。"
        }
    }

    func stop() {
        sessionID = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        recognition?.cancel()
        recognition = nil
        request = nil
        isRecording = false
        isStarting = false
        level = 0
        // 取出本次录音的 WAV（若采集到），随后释放采集器，避免同一段音频被重复上传。
        let captured = accumulator?.makeWAVData()
        accumulator = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // 云端增强转写：仅在联网 + 用户开启开关时触发；失败自动回落到已获得的 Apple 本机转写。
        transcribeInCloud(audio: captured)
    }

    /// 云端转写（可选增强，默认关闭）。
    ///
    /// - 离线（`useRemoteAPI == false`，含 UI 测试）或用户未开启开关时**完全不发网络请求**；
    /// - 成功且返回文本非空 → 覆盖 ``transcript``（对话页据此把文字填入输入框）；
    /// - 失败 / 返回空 → 保留 Apple 本机转写；仅当本机也没有任何文字时才给出低调提示。
    private func transcribeInCloud(audio: Data?) {
        guard AppConfiguration.useRemoteAPI else { return }
        guard UserDefaults.standard.bool(forKey: SpeechSettingsKeys.cloudEnabled) else { return }
        guard let audio, audio.count > 44 else { return }
        let storedDialect = UserDefaults.standard.string(forKey: SpeechSettingsKeys.dialect) ?? SpeechDialect.zh.rawValue
        let dialect = SpeechDialect(rawValue: storedDialect) ?? .zh
        let fallback = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        isTranscribing = true
        Task { @MainActor in
            defer { isTranscribing = false }
            do {
                let result = try await SpeechTranscriptionService().transcribe(
                    audioData: audio,
                    filename: "speech.wav",
                    mime: "audio/wav",
                    languageHints: dialect.hints
                )
                if result.hasText {
                    transcript = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if fallback.isEmpty {
                    error = "没有听清，请重试或改用键盘输入。"
                }
            } catch {
                // 回落到本机转写：已有文字则静默保留，仅在完全无文字时低调提示。
                if fallback.isEmpty {
                    self.error = "云端识别暂不可用，已保留本机识别结果，可重试或改用键盘输入。"
                }
            }
        }
    }
}
