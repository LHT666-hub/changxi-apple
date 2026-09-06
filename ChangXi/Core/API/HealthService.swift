import Foundation

protocol ConversationService: Sendable {
    func reply(to message: String) async throws -> String
}

/// Deterministic demo responses; no clinical inference or network requests.
struct DemoConversationService: ConversationService {
    func reply(to message: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(1200))
        try Task.checkCancellation()
        if message.contains("报告") { return "我们可以先核对报告日期、项目名称、单位和报告列出的参考区间。你也可以打开健康页的报告示例，查看各项数据如何整理。\n\n这是体验版示例回复，尚未读取或分析你的报告。" }
        if message.contains("药") { return "可以先把药名、本人处方中的用法和想问的问题记下来，再向医生或药师核对。\n\n我可以带你查看用药计划。这是示例对话，不会调整你的用药安排。" }
        if message.contains("头晕") || message.contains("不舒服") { return "我听到了。可以记下从什么时候开始、持续多久，以及当时的感受，方便与医生沟通。\n\n当前是体验模式，我无法判断症状或提供实时诊疗。若你需要医疗帮助，请直接联系当地医疗服务。" }
        return "我在这里。你可以记下一次测量，看看今天的计划，或把想问医生的问题整理成草稿。\n\n这是一条体验版示例回复；你的文字仅保存在本机。"
    }
}

struct RemoteConversationService: ConversationService {
    let baseURL: URL
    func reply(to message: String) async throws -> String {
        struct Request: Encodable { let message: String }
        struct Response: Decodable { let reply: String }
        guard baseURL.scheme == "https" else { throw URLError(.secureConnectionFailed) }
        var request = URLRequest(url: baseURL.appending(path: "api/v1/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(message: message))
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Response.self, from: data).reply
    }
}
