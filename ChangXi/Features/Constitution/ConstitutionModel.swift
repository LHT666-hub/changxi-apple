import Foundation
import SwiftUI
import Observation

enum TCMConstitution: String, CaseIterable, Codable, Identifiable, Hashable {
    case balanced = "平和质"
    case qiDeficiency = "气虚质"
    case yangDeficiency = "阳虚质"
    case yinDeficiency = "阴虚质"
    case phlegmDamp = "痰湿质"
    case dampHeat = "湿热质"
    case bloodStasis = "血瘀质"
    case qiStagnation = "气郁质"
    case special = "特禀质"

    var id: Self { self }
    var atlasIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var shortDescription: String {
        switch self {
        case .balanced: "阴阳调和 · 精力平稳"
        case .qiDeficiency: "容易疲乏 · 气短懒言"
        case .yangDeficiency: "较为怕冷 · 手脚易凉"
        case .yinDeficiency: "容易口干 · 手足心热"
        case .phlegmDamp: "身体困重 · 口中黏腻"
        case .dampHeat: "面部易油 · 口苦心烦"
        case .bloodStasis: "肤色偏暗 · 容易瘀青"
        case .qiStagnation: "容易叹气 · 情绪郁闷"
        case .special: "容易过敏 · 适应敏感"
        }
    }
    var gentlePhrase: String {
        switch self {
        case .balanced: "保持现在的节律"
        case .qiDeficiency: "把力气慢慢养回来"
        case .yangDeficiency: "温和活动，注意保暖"
        case .yinDeficiency: "留一点安静与滋润"
        case .phlegmDamp: "轻盈活动，规律饮食"
        case .dampHeat: "清爽作息，少些闷热"
        case .bloodStasis: "舒展身体，避免久坐"
        case .qiStagnation: "舒展心情，保持往来"
        case .special: "留意诱因，减少接触"
        }
    }
    var tint: Color {
        switch self {
        case .balanced: Color(red: 0.72, green: 0.74, blue: 0.58)
        case .qiDeficiency: Color(red: 0.52, green: 0.67, blue: 0.72)
        case .yangDeficiency: Color(red: 0.77, green: 0.62, blue: 0.52)
        case .yinDeficiency: Color(red: 0.59, green: 0.60, blue: 0.76)
        case .phlegmDamp: Color(red: 0.52, green: 0.68, blue: 0.57)
        case .dampHeat: Color(red: 0.64, green: 0.69, blue: 0.48)
        case .bloodStasis: Color(red: 0.72, green: 0.51, blue: 0.54)
        case .qiStagnation: Color(red: 0.69, green: 0.61, blue: 0.50)
        case .special: Color(red: 0.56, green: 0.67, blue: 0.75)
        }
    }
    var commonSigns: [String] {
        shortDescription.components(separatedBy: " · ")
    }
    var suggestions: [String] {
        switch self {
        case .balanced: ["规律作息", "饮食多样", "保持活动", "顺应季节"]
        case .qiDeficiency: ["量力活动", "保证休息", "三餐规律", "观察疲劳"]
        case .yangDeficiency: ["注意保暖", "温和活动", "避免久坐", "留意不适"]
        case .yinDeficiency: ["规律饮水", "避免熬夜", "舒缓活动", "减少燥热"]
        case .phlegmDamp: ["循序活动", "清淡规律", "避免久坐", "记录体重"]
        case .dampHeat: ["作息清爽", "少油少酒", "保持通风", "留意皮肤"]
        case .bloodStasis: ["轻柔舒展", "避免久坐", "注意保暖", "记录疼痛"]
        case .qiStagnation: ["户外散步", "保持社交", "练习放松", "说出感受"]
        case .special: ["记录诱因", "减少接触", "随身备忘", "及时求助"]
        }
    }
}

struct ConstitutionQuestion: Identifiable {
    let id: Int
    let constitution: TCMConstitution
    let text: String
}

extension ConstitutionQuestion {
    static let brief: [Self] = [
        .init(id: 1, constitution: .balanced, text: "最近三个月，您的精力总体充沛吗？"),
        .init(id: 2, constitution: .qiDeficiency, text: "您容易疲乏，稍微活动就觉得累吗？"),
        .init(id: 3, constitution: .qiDeficiency, text: "您容易气短，或说话声音没有力气吗？"),
        .init(id: 4, constitution: .yangDeficiency, text: "您的手脚容易发凉吗？"),
        .init(id: 5, constitution: .yangDeficiency, text: "您比别人更怕冷或怕风吗？"),
        .init(id: 6, constitution: .yinDeficiency, text: "您经常感到口干咽燥吗？"),
        .init(id: 7, constitution: .yinDeficiency, text: "您的手心或脚心容易发热吗？"),
        .init(id: 8, constitution: .phlegmDamp, text: "您常觉得身体沉重、不轻松吗？"),
        .init(id: 9, constitution: .phlegmDamp, text: "您常觉得嘴里发黏，或痰比较多吗？"),
        .init(id: 10, constitution: .dampHeat, text: "您的面部或鼻部容易出油吗？"),
        .init(id: 11, constitution: .dampHeat, text: "您容易口苦，或大便黏滞不爽吗？"),
        .init(id: 12, constitution: .bloodStasis, text: "您的皮肤容易出现青紫瘀斑吗？"),
        .init(id: 13, constitution: .bloodStasis, text: "您有位置固定、像针扎一样的不适吗？"),
        .init(id: 14, constitution: .qiStagnation, text: "您容易情绪低落、闷闷不乐吗？"),
        .init(id: 15, constitution: .qiStagnation, text: "您容易紧张、焦虑或经常叹气吗？"),
        .init(id: 16, constitution: .special, text: "您没有感冒时也会打喷嚏、鼻塞或流鼻涕吗？"),
        .init(id: 17, constitution: .special, text: "您的皮肤容易因食物、药物或环境出现过敏吗？"),
        .init(id: 18, constitution: .balanced, text: "您对季节和生活环境的变化适应良好吗？")
    ]
}

enum ConstitutionReviewStatus: String, Codable, Equatable {
    case draft = "常曦初测"
    case pending = "待家庭医生确认"
    case confirmed = "家庭医生已确认"
}

struct ConstitutionResult: Codable {
    var date = Date.now
    var scores: [String: Int]
    var status: ConstitutionReviewStatus = .draft

    var ranked: [(TCMConstitution, Int)] {
        TCMConstitution.allCases.map { ($0, scores[$0.rawValue] ?? 0) }.sorted { $0.1 > $1.1 }
    }
    var primary: TCMConstitution { ranked.first?.0 ?? .balanced }
    var secondary: TCMConstitution? {
        guard ranked.count > 1, ranked[1].1 > 0 else { return nil }
        return ranked[1].0
    }
}

@MainActor @Observable
final class ConstitutionStore {
    private(set) var result: ConstitutionResult?
    private let key = "changxi.constitution.result.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        result = try? JSONDecoder().decode(ConstitutionResult.self, from: data)
    }
    func save(scores: [TCMConstitution: Int]) {
        let encoded = Dictionary(uniqueKeysWithValues: scores.map { ($0.key.rawValue, $0.value) })
        result = ConstitutionResult(scores: encoded)
        persist()
    }
    func requestDoctorReview() {
        result?.status = .pending
        persist()
    }
    private func persist() {
        guard let result, let data = try? JSONEncoder().encode(result) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
