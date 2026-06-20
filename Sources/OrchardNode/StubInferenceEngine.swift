import OrchardProtocol

// A deterministic engine that synthesizes a schema-conformant payload without any model. Used
// by tests, the demo executable, and any CI runner lacking the Foundation Models SDK. Output is
// derived from the prompt so results are stable and assertable.

public struct StubInferenceEngine: InferenceEngine {
    public let identifier = "stub"

    public init() {}

    public func run(_ request: InferenceRequest) async throws -> InferenceResponse {
        var payload: [String: JSONValue] = [:]
        for field in request.schema.fields {
            payload[field.name] = Self.placeholder(for: field, prompt: request.prompt)
        }
        return InferenceResponse(payload: payload, rawText: "stub(\(request.prompt.count) chars)")
    }

    private static func placeholder(for field: SchemaField, prompt: String) -> JSONValue {
        switch field.type {
        case .string: .string("stub:\(field.name)")
        case .number: .number(Double(prompt.count))
        case .boolean: .boolean(true)
        case .array: .array([])
        case .object: .object([:])
        case .null: .null
        }
    }
}
