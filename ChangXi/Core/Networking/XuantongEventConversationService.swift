import Foundation

struct XuantongEventReply: Sendable {
    enum ClinicalRisk: String, Decodable, Equatable, Sendable {
        case green, yellow, red
    }

    let text: String
    let clinicalRisk: ClinicalRisk?
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

        struct Workflow: Decodable {
            let status: String
            let patientCommunication: String?
            let clinicalRisk: String?

            enum CodingKeys: String, CodingKey {
                case status
                case patientCommunication = "patient_communication"
                case clinicalRisk = "clinical_risk"
            }
        }
    }

    let baseURL: URL
    var session: URLSession = .shared

    static func configured() -> Self {
        let environment = ProcessInfo.processInfo.environment["XUANTONG_BASE_URL"]
        let url = environment.flatMap(URL.init(string:)) ?? AppConfiguration.apiBaseURL
        return Self(baseURL: url)
    }

    func reply(to message: String, patientID: String) async throws -> XuantongEventReply {
        guard baseURL.scheme == "https" || AppConfiguration.isLocalDevelopment(baseURL) else {
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
        request.timeoutInterval = 90

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
            clinicalRisk: event.workflow.clinicalRisk.flatMap(XuantongEventReply.ClinicalRisk.init(rawValue:))
        )
    }
}
