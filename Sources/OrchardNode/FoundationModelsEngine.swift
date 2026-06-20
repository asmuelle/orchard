#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import OrchardProtocol

    // The real on-device engine: runs native inference on the Neural Engine via Apple's Foundation
    // Models framework. Compiled in only where the SDK exists (Xcode 26+ / OS 26+); elsewhere the
    // runtime uses StubInferenceEngine. Asks the model for a single JSON object matching the task
    // schema, then parses it into the wire payload. A future revision can switch to the typed
    // `@Generable` guided-generation path for stronger guarantees.

    @available(macOS 26.0, iOS 26.0, *)
    public struct FoundationModelsEngine: InferenceEngine {
        public let identifier = "foundation-models"

        public init() {}

        public enum EngineError: Error, Sendable {
            case modelUnavailable(String)
            case unparseableOutput(String)
        }

        public func run(_ request: InferenceRequest) async throws -> InferenceResponse {
            switch SystemLanguageModel.default.availability {
            case .available:
                break
            case let .unavailable(reason):
                throw EngineError.modelUnavailable("\(reason)")
            @unknown default:
                throw EngineError.modelUnavailable("unknown")
            }

            let session = LanguageModelSession()
            let prompt = "\(Self.instruction(for: request.schema))\n\nTask:\n\(request.prompt)"
            let response = try await session.respond(to: prompt)
            let text = response.content

            guard let payload = Self.parsePayload(text) else {
                throw EngineError.unparseableOutput(text)
            }
            return InferenceResponse(payload: payload, rawText: text)
        }

        static func instruction(for schema: StructuredSchema) -> String {
            let shape = schema.fields
                .map { "\"\($0.name)\": <\($0.type.rawValue)>" }
                .joined(separator: ", ")
            return "Respond with a single JSON object and nothing else, matching: { \(shape) }."
        }

        static func parsePayload(_ text: String) -> [String: JSONValue]? {
            let cleaned = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            guard let start = cleaned.firstIndex(of: "{"),
                  let end = cleaned.lastIndex(of: "}"),
                  start < end
            else { return nil }
            let slice = String(cleaned[start ... end])
            guard let data = slice.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([String: JSONValue].self, from: data)
        }
    }
#endif
