import Foundation

struct XuantongEventReply: Sendable {
    enum ClinicalRisk: String, Decodable, Equatable, Sendable {
        case green, yellow, red
    }

    let text: String
    let clinicalRisk: ClinicalRisk?
    let actionSummary: String?
    let steps: [String]
    let references: [ConversationReference]
    let workOrders: [ConversationWorkOrder]
}

/// The conversation adapter for the contract currently exposed by `xuantong/main`.
struct XuantongEventConversationService: Sendable {
    private struct EventRequest: Encodable {
        let patientID: String
        let eventType = "patient.message.received"
        let channel = "changxi"
        let source = "changxi-ios"
        let payload: Payload
        let metadata: Metadata

        enum CodingKeys: String, CodingKey {
            case patientID = "patient_id"
            case eventType = "event_type"
            case channel, source, payload, metadata
        }

        struct Payload: Encodable { let message: String }
        struct Metadata: Encodable {
            let client = "ios"
            let contractVersion = "xuantong-events-v1"

            enum CodingKeys: String, CodingKey {
                case client
                case contractVersion = "contract_version"
            }
        }
    }

    private struct EventResponse: Decodable {
        let workflow: Workflow
        let tasks: [Task]?

        struct Workflow: Decodable {
            let status: String
            let patientCommunication: String?
            let clinicalRisk: String?
            let actionSummary: String?
            let steps: [String]?
            let references: [ConversationReference]?

            enum CodingKeys: String, CodingKey {
                case status
                case patientCommunication = "patient_communication"
                case clinicalRisk = "clinical_risk"
                case actionSummary = "action_summary"
                case steps, references
            }
        }

        struct Task: Decodable {
            let id: String
            let title: String
            let description: String
            let taskType: String
            let status: String
            let priority: String
            let assigneeRole: String?
            let deadline: String?

            enum CodingKeys: String, CodingKey {
                case id, title, description, status, priority, deadline
                case taskType = "task_type"
                case assigneeRole = "assignee_role"
            }
        }
    }

    let baseURL: URL
    var session: URLSession = .shared

    static func configured() -> Self {
        Self(baseURL: AppConfiguration.apiBaseURL)
    }

    func reply(to message: String, patientID: String) async throws -> XuantongEventReply {
        guard baseURL.scheme == "https" || AppConfiguration.allowsInsecureHTTP(baseURL) else {
            throw URLError(.secureConnectionFailed)
        }
        var request = URLRequest(url: baseURL.appending(path: "api/events"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            EventRequest(
                patientID: patientID,
                payload: .init(message: message),
                metadata: .init()
            )
        )
        request.timeoutInterval = 180

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let event = try JSONDecoder().decode(EventResponse.self, from: data)
        guard event.workflow.status != "failed" else { throw URLError(.cannotParseResponse) }
        guard let reply = event.workflow.patientCommunication?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reply.isEmpty else {
            throw URLError(.zeroByteResource)
        }
        return XuantongEventReply(
            text: reply,
            clinicalRisk: event.workflow.clinicalRisk.flatMap(XuantongEventReply.ClinicalRisk.init(rawValue:)),
            actionSummary: event.workflow.actionSummary,
            steps: event.workflow.steps ?? [],
            references: event.workflow.references ?? [],
            workOrders: (event.tasks ?? []).map {
                ConversationWorkOrder(
                    id: $0.id,
                    title: $0.title,
                    description: $0.description,
                    taskType: $0.taskType,
                    status: $0.status,
                    priority: $0.priority,
                    assigneeRole: $0.assigneeRole,
                    deadline: $0.deadline
                )
            }
        )
    }
}
