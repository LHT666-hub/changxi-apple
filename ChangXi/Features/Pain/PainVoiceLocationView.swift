import SwiftUI
import AVFoundation

struct PainLocationSuggestion {
    let region: PainRegion
    let angle: PainAngle
    let name: String
    let coordinate: PainCoordinate
}

/// Conservative vocabulary matching. A suggestion is never a confirmed record.
enum PainLocationVocabulary {
    static func resolve(_ text: String) -> (suggestion: PainLocationSuggestion?, question: String) {
        let text = text.replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return (nil, "先说说哪里疼，例如：左边太阳穴，一跳一跳的。") }
        // Corrections, negation and several sites need clarification instead of keyword guessing.
        let ambiguous = ["不疼", "不痛", "不是", "不在", "没有", "改成", "还有", "以及", "两边", "两侧", "都疼", "都痛"]
        if ambiguous.contains(where: { text.contains($0) }) || (text.contains("左") && text.contains("右")) {
            return (nil, "我们一次确认一个地方。请重新说现在要标的位置，例如：左太阳穴。也可以直接在图上指。")
        }
        let entries: [(aliases: [String], region: PainRegion, angle: PainAngle, name: String, x: Double, y: Double)] = [
            (["太阳穴"], .head, .front, "太阳穴", 0.31, 0.36),
            (["额头", "脑门", "前额"], .head, .front, "额头", 0.5, 0.25),
            (["后脑", "后脑勺"], .head, .back, "后脑勺", 0.5, 0.43),
            (["头顶"], .head, .front, "头顶", 0.5, 0.12),
            (["下巴", "下颌"], .head, .front, "下颌", 0.5, 0.64),
            (["耳朵", "耳边", "耳周"], .head, .left, "耳周", 0.56, 0.43),
            (["后颈", "脖子后面"], .head, .back, "后颈", 0.5, 0.75),
            (["肩膀", "肩头", "肩部"], .neck, .front, "肩部", 0.75, 0.25),
            (["胸口", "胸前正中"], .torso, .front, "胸口正中", 0.5, 0.20),
            (["左胸", "右胸", "胸部一侧"], .torso, .front, "胸部", 0.5, 0.23),
            (["上腹", "心窝", "胃口"], .torso, .front, "上腹", 0.5, 0.36),
            (["肚脐"], .torso, .front, "肚脐周围", 0.5, 0.48),
            (["小肚子", "下腹"], .torso, .front, "下腹", 0.5, 0.62),
            (["肩胛骨", "肩胛"], .back, .back, "肩胛周围", 0.5, 0.24),
            (["上背", "背上面"], .back, .back, "上背", 0.5, 0.30),
            (["腰", "腰部", "后腰"], .back, .back, "腰部", 0.5, 0.55),
            (["尾骨", "骶尾"], .back, .back, "骶尾部", 0.5, 0.76),
            (["上臂", "大胳膊"], .arms, .front, "上臂", 0.5, 0.29),
            (["胳膊肘", "肘部", "手肘"], .arms, .front, "肘部", 0.5, 0.48),
            (["前臂", "小胳膊"], .arms, .front, "前臂", 0.5, 0.61),
            (["手腕", "腕关节"], .arms, .front, "手腕", 0.5, 0.76),
            (["手掌", "手心"], .arms, .front, "手掌", 0.5, 0.88),
            (["髋", "胯", "胯骨"], .legs, .front, "髋部", 0.5, 0.14),
            (["大腿"], .legs, .front, "大腿", 0.5, 0.29),
            (["膝盖", "膝关节"], .legs, .front, "膝盖", 0.5, 0.48),
            (["小腿", "腿肚子"], .legs, .back, "小腿", 0.5, 0.66),
            (["脚踝", "踝关节"], .legs, .front, "脚踝", 0.5, 0.83),
            (["脚背"], .legs, .front, "脚背", 0.5, 0.92),
            (["脚底", "脚心"], .legs, .back, "脚底", 0.5, 0.94)
        ]
        let matches = entries.filter { entry in entry.aliases.contains(where: text.contains) }
        guard matches.count == 1, let entry = matches.first else {
            return (nil, matches.isEmpty ? "还没确定具体位置。是额头、太阳穴、后脑勺，还是其他地方？你也可以在图上点给我看。" : "听到了不止一个地方。我们先选一个位置，确认后再加下一处。")
        }
        let sided = ["太阳穴", "耳周", "肩部", "胸部", "肩胛周围", "腰部", "上臂", "肘部", "前臂", "手腕", "手掌", "髋部", "大腿", "膝盖", "小腿", "脚踝", "脚背", "脚底"].contains(entry.name)
        let left = text.contains("左"), right = text.contains("右")
        if !sided && (left || right) {
            return (nil, "你提到了偏左或偏右的位置。请在图上点出具体地方，我先不把它标在正中间。")
        }
        if sided && !left && !right { return (nil, "\(entry.name)是你身体的左边，还是右边？请说完整位置，比如“左\(entry.name)”。") }
        var x = entry.x
        var angle = entry.angle
        if entry.name == "太阳穴" { x = left ? 0.69 : 0.31 }
        if entry.name == "耳周" { angle = left ? .left : .right; x = left ? 0.56 : 0.44 }
        if entry.name == "肩部" { x = left ? 0.75 : 0.25 }
        if entry.name == "膝盖" { x = left ? 0.63 : 0.37 }
        if sided && !["太阳穴", "耳周", "肩部", "膝盖"].contains(entry.name) {
            x = entry.angle == .back ? (left ? 0.35 : 0.65) : (left ? 0.65 : 0.35)
        }
        let name = (sided ? (left ? "左" : "右") : "") + entry.name
        let suggestion = PainLocationSuggestion(region: entry.region, angle: angle, name: name, coordinate: PainCoordinate(x: x, y: entry.y))
        return (suggestion, "我先标在\(name)。是这里吗？不准的话，可以点图调整。")
    }
}

struct PainVoiceLocationView: View {
    let confirm: (PainRegion, PainAngle, [PainMark]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var speech = SpeechController()
    @State private var speaker = AVSpeechSynthesizer()
    @State private var text = ""
    @State private var question = "你说哪里疼，我先帮你标出来，再一起核对。"
    @State private var suggestion: PainLocationSuggestion?
    @State private var candidateMarks: [PainMark] = []
    @State private var recognizedText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image("ChangXiCharacter").resizable().scaledToFit().frame(width: 76, height: 76)
                    Text(question).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
                Card {
                    TextField("例如：左边太阳穴，一跳一跳的", text: $text, axis: .vertical)
                        .lineLimit(2...5).disabled(speech.isRecording || speech.isStarting || speech.isTranscribing)
                    Button {
                        speaker.stopSpeaking(at: .immediate)
                        if speech.isRecording || speech.isStarting { speech.stop() }
                        else { suggestion = nil; candidateMarks = []; Task { await speech.start() } }
                    } label: {
                        Label(speech.isRecording ? "说完了" : speech.isStarting ? "正在准备麦克风…" : "说给常曦听", systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.borderedProminent).disabled(speech.isTranscribing)
                    if speech.isRecording { Text("正在听，点“说完了”结束。文字可以在结束后修改。").font(.footnote).foregroundStyle(CX.muted) }
                    if speech.isTranscribing { ProgressView("正在整理语音…") }
                    if let error = speech.error { Text(error).font(.footnote).foregroundStyle(CX.coral) }
                    Button("请常曦标出来") { locate() }
                        .buttonStyle(PrimaryButton())
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speech.isRecording || speech.isStarting || speech.isTranscribing)
                }
                if let suggestion {
                    Label("待你确认 · \(suggestion.name)", systemImage: "questionmark.circle")
                        .font(.headline).foregroundStyle(CX.blue)
                    PainMarkingSurface(region: suggestion.region, angle: suggestion.angle, kind: .point, marks: Binding(
                        get: { candidateMarks },
                        set: { value in
                            // A new tap moves the candidate; it does not create another confirmed site.
                            candidateMarks = value.last.map { mark in
                                var adjusted = mark
                                adjusted.name = "手动调整的位置"
                                return [adjusted]
                            } ?? []
                        }
                    ))
                    Button("对，就是这里") {
                        guard text == recognizedText, !candidateMarks.isEmpty else { return }
                        confirm(suggestion.region, suggestion.angle, candidateMarks)
                        dismiss()
                    }.buttonStyle(PrimaryButton())
                    Button("不是，我再说一次") {
                        self.suggestion = nil; candidateMarks = []
                        question = "好，我们重新来。请说你身体哪一边、哪个地方疼。"
                    }.frame(maxWidth: .infinity, minHeight: 48)
                }
                Button { readQuestion() } label: { Label("听常曦读出来", systemImage: "speaker.wave.2") }
                    .disabled(speech.isRecording || speech.isStarting || speech.isTranscribing)
                Text("先帮你定位，确认后才加入这次记录。说不清时也可以回去点图。").font(.footnote).foregroundStyle(CX.muted)
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("说给常曦听").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回点图") { dismiss() } } }
        .onChange(of: speech.transcript) { _, value in text = value }
        .onChange(of: text) { _, value in
            if value != recognizedText { suggestion = nil; candidateMarks = []; speaker.stopSpeaking(at: .immediate) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { if speech.isRecording || speech.isStarting { speech.stop() }; speaker.stopSpeaking(at: .immediate) }
        }
        .onDisappear { if speech.isRecording || speech.isStarting { speech.stop() }; speaker.stopSpeaking(at: .immediate) }
    }

    private func locate() {
        let result = PainLocationVocabulary.resolve(text)
        recognizedText = text
        suggestion = result.suggestion
        question = result.question
        candidateMarks = result.suggestion.map { [PainMark(angle: $0.angle, kind: .point, points: [$0.coordinate], name: $0.name)] } ?? []
        // Keep speech playback user-initiated to avoid unexpected audio and VoiceOver overlap.
    }

    private func readQuestion() {
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: question)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.43
        speaker.speak(utterance)
    }
}
