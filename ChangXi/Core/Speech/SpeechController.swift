import AVFoundation
import Speech
import Observation

@MainActor @Observable
final class SpeechController {
    var isRecording = false
    var isStarting = false
    var level = 0.0
    var transcript = ""
    var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var hasTap = false
    private var sessionID = UUID()

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
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw URLError(.cannotLoadFromNetwork) }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
