import OrchardProtocol

// Abstraction over on-device inference. The real implementation is the Foundation Models
// adapter (compiled in only on OS 26+); tests and CI use the deterministic stub. Keeping this
// a protocol means the scheduler/runtime never depend on the AFM SDK being present.

public struct InferenceRequest: Sendable {
    public let prompt: String
    public let schema: StructuredSchema

    public init(prompt: String, schema: StructuredSchema) {
        self.prompt = prompt
        self.schema = schema
    }
}

public struct InferenceResponse: Sendable {
    public let payload: [String: JSONValue]
    public let rawText: String

    public init(payload: [String: JSONValue], rawText: String) {
        self.payload = payload
        self.rawText = rawText
    }
}

public protocol InferenceEngine: Sendable {
    /// Human-readable engine identifier (e.g. "foundation-models", "stub").
    var identifier: String { get }
    func run(_ request: InferenceRequest) async throws -> InferenceResponse
}
