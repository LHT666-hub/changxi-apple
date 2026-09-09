import AVFoundation
import Foundation

// MARK: - 语音转写设置键（UserDefaults）

/// 云端语音识别相关的 ``UserDefaults`` 键。
///
/// 之所以用 `UserDefaults` 而非 ``AppStore`` / `LocalState`：语音偏好属于设备级设置，
/// 且 ``AppStore`` 的 `LocalState` 结构由其他任务维护，这里避免与其产生耦合与冲突。
/// 设置界面（``SpeechSettingsView``）写入，``SpeechController`` 读取。
enum SpeechSettingsKeys {
    /// 是否启用云端语音识别（默认关闭 → 仅走 Apple 本机识别）。
    static let cloudEnabled = "changxi.cloudSpeechEnabled"
    /// 云端识别的方言 / 语言（存储 ``SpeechDialect`` 的 `rawValue`，默认 `zh`）。
    static let dialect = "changxi.cloudSpeechDialect"
}

// MARK: - 方言 / 语言

/// 语音识别的地区口音偏好，映射到后端 `language_hints` 。
/// 省市选项以江浙沪皖为核心向周边扩展；后端不可用时仍保留偏好，并回落到 Apple 本机识别。
enum SpeechDialect: String, CaseIterable, Identifiable {
    case zh
    case shanghai
    case jiangsu
    case zhejiang
    case anhui
    case jiangxi
    case fujian
    case hubei
    case hunan
    case guangdong
    case sichuan

    var id: Self { self }

    /// 界面展示名称。
    var label: String {
        switch self {
        case .zh: "普通话"
        case .shanghai: "上海·沪语"
        case .jiangsu: "江苏·苏州话 / 江淮官话"
        case .zhejiang: "浙江·吴语"
        case .anhui: "安徽·江淮官话"
        case .jiangxi: "江西·赣语"
        case .fujian: "福建·闽南语"
        case .hubei: "湖北·武汉话"
        case .hunan: "湖南·湘语"
        case .guangdong: "广东·粤语"
        case .sichuan: "四川·西南官话"
        }
    }

    /// 上传给后端的语言与方言提示。
    var hints: [String] {
        switch self {
        case .zh: ["zh"]
        case .guangdong: ["yue", "zh"]
        case .fujian: ["mn", "zh"]
        case .sichuan: ["sc", "zh"]
        case .shanghai, .jiangsu, .zhejiang, .anhui, .jiangxi, .hubei, .hunan: ["zh"]
        }
    }

    /// 兼容旧版曾直接保存的方言代码。
    static func fromStoredValue(_ value: String) -> SpeechDialect {
        if let dialect = SpeechDialect(rawValue: value) { return dialect }
        return switch value {
        case "yue": .guangdong
        case "sc": .sichuan
        case "mn": .fujian
        default: .zh
        }
    }
}

// MARK: - 转写结果模型

/// `POST /api/v1/speech/transcribe` 的响应体。
///
/// 字段经 ``APIClient`` 的 `.convertFromSnakeCase` 转换：`duration_ms` → `durationMs`。
/// - Note: `durationMs` 后端在非 WAV 格式下可能恒为 0；`confidence` 为后端占位值，
///   不是真实测量，UI 不应对其做强依赖。
struct Transcription: Decodable {
    /// 转写文本（后端失败时可能为空字符串）。
    let text: String
    /// 识别到的语言（默认 `zh`）。
    let language: String
    /// 音频时长（毫秒），可能为 0。
    let durationMs: Int
    /// 置信度占位值（0–1），不可作为可信指标。
    let confidence: Double
    /// 情绪标签，仅在 `with_emotion` 时有意义，否则为空字符串。
    let emotion: String

    /// 时长是否有意义（> 0）；为 0 时 UI 应直接隐藏该信息，不显示“0 毫秒”。
    var hasDuration: Bool { durationMs > 0 }
    /// 去除首尾空白后是否非空。
    var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - WAV 编码

/// 手写 44 字节 RIFF/WAVE 头，将 16-bit PCM 裸数据封装为 WAV。
///
/// 不引入任何第三方音频库；仅用系统字节序转换（`littleEndian`）保证跨设备正确。
enum WAVEncoder {
    /// 将小端 16-bit PCM 裸数据封装为 WAV。
    /// - Parameters:
    ///   - pcm: 小端 16-bit PCM 采样数据（单声道或多声道交错）。
    ///   - sampleRate: 采样率（Hz）。
    ///   - channels: 声道数。
    ///   - bitsPerSample: 位深（固定 16）。
    static func encode(pcm: Data, sampleRate: Double, channels: Int, bitsPerSample: Int = 16) -> Data {
        let channelCount = max(1, channels)
        let bits = max(8, bitsPerSample)
        let rate = sampleRate > 0 ? Int(sampleRate) : 16000
        let byteRate = rate * channelCount * bits / 8
        let blockAlign = channelCount * bits / 8

        var out = Data(capacity: 44 + pcm.count)
        func ascii(_ string: String) { out.append(Data(string.utf8)) }
        func u32(_ value: Int) {
            var little = UInt32(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &little) { out.append(contentsOf: $0) }
        }
        func u16(_ value: Int) {
            var little = UInt16(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &little) { out.append(contentsOf: $0) }
        }

        ascii("RIFF")
        u32(36 + pcm.count)          // ChunkSize = 36 + SubChunk2Size
        ascii("WAVE")
        ascii("fmt ")
        u32(16)                      // Subchunk1Size（PCM = 16）
        u16(1)                       // AudioFormat（1 = PCM）
        u16(channelCount)
        u32(rate)
        u32(byteRate)
        u16(blockAlign)
        u16(bits)
        ascii("data")
        u32(pcm.count)
        out.append(pcm)
        return out
    }
}

// MARK: - PCM 采集缓冲

/// 线程安全的单声道 16-bit PCM 采集器。
///
/// ``AVAudioEngine`` 的 tap 回调运行在音频线程，而 ``SpeechController`` 为 `@MainActor`
/// 隔离；为避免跨隔离域访问属性，采集器作为独立的 `@unchecked Sendable` 对象，
/// 由 tap 闭包**按值强捕获**（不经 `self`），内部用 `NSLock` 保护累积缓冲。
final class PCMAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    /// 累积的小端 16-bit PCM 数据。
    private var pcm = Data()
    private var frameCount = 0
    private var sampleRate: Double = 16000

    /// 追加一个 PCM 缓冲（float32 → 小端 int16，取第 0 声道）。
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let rate = buffer.format.sampleRate

        var chunk = Data(capacity: frames * 2)
        for index in 0..<frames {
            let clamped = max(-1.0, min(1.0, channel[index]))
            let sample = Int16(clamped * Float(Int16.max))
            // 显式小端写入（与 WAV 规范一致，不依赖宿主字节序）。
            chunk.append(UInt8(truncatingIfNeeded: sample))
            chunk.append(UInt8(truncatingIfNeeded: sample >> 8))
        }

        lock.lock()
        pcm.append(chunk)
        frameCount += frames
        if rate > 0 { sampleRate = rate }
        lock.unlock()
    }

    /// 生成 WAV 数据；无有效采样时返回 `nil`。
    func makeWAVData() -> Data? {
        lock.lock()
        let data = pcm
        let frames = frameCount
        let rate = sampleRate
        lock.unlock()
        guard frames > 0, !data.isEmpty else { return nil }
        return WAVEncoder.encode(pcm: data, sampleRate: rate, channels: 1, bitsPerSample: 16)
    }
}

// MARK: - 语音转写服务

/// 云端语音转写服务：桥接后端 `POST /api/v1/speech/transcribe`。
///
/// 走 ``APIClient/postMultipart``（`multipart/form-data`，字段名 `file`），复用统一网络层，
/// 不自行构造 `URLRequest`。`Sendable`（仅持有 `Sendable` 的 ``APIClient``），可在任意并发上下文使用。
struct SpeechTranscriptionService: Sendable {
    let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    /// 上传音频并转写。
    /// - Parameters:
    ///   - audioData: 音频字节（推荐 WAV，16-bit PCM 单声道）。
    ///   - filename: 上传文件名（如 `speech.wav`）。
    ///   - mime: MIME 类型（如 `audio/wav`）。
    ///   - languageHints: 方言提示，映射到后端 `language_hints`（逗号分隔）。
    ///   - withEmotion: 是否请求情绪识别，映射到后端 `with_emotion`。
    /// - Returns: 后端转写结果 ``Transcription``。
    /// - Throws: ``APIError``（网络 / 校验 / 502 转写失败 / 解码）。
    func transcribe(
        audioData: Data,
        filename: String,
        mime: String,
        languageHints: [String] = ["zh"],
        withEmotion: Bool = false
    ) async throws -> Transcription {
        var fields: [String: String] = [:]
        if !languageHints.isEmpty {
            fields["language_hints"] = languageHints.joined(separator: ",")
        }
        if withEmotion {
            fields["with_emotion"] = "true"
        }
        return try await api.postMultipart(
            "speech/transcribe",
            fields: fields,
            file: (name: "file", filename: filename, mime: mime, data: audioData),
            prefix: .v1
        )
    }
}
