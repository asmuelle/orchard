import Foundation
import OrchardNode
import OrchardProtocol

// The compute an edge node runs for a folding task. Unlike the LLM path, this is a deterministic
// scientific kernel: parse the candidate conformation from the task prompt, evaluate its energy,
// return it as structured output. Determinism is the point — honest nodes produce identical
// payloads and therefore agree under consensus, while a faulty node stands out.

public struct FoldingEngine: InferenceEngine {
    public let identifier = "folding"

    public init() {}

    public func run(_ request: InferenceRequest) async throws -> InferenceResponse {
        let theta = try CandidateCodec.decode(request.prompt)
        let energy = FoldingModel.energy(theta)
        return InferenceResponse(payload: ["energy": .number(energy)], rawText: "\(energy)")
    }
}

/// A node that returns a wrong energy — used to prove consensus rejects it.
public struct FaultyFoldingEngine: InferenceEngine {
    public let identifier = "folding-faulty"

    public init() {}

    public func run(_ request: InferenceRequest) async throws -> InferenceResponse {
        let theta = try CandidateCodec.decode(request.prompt)
        let wrong = FoldingModel.energy(theta) + 100
        return InferenceResponse(payload: ["energy": .number(wrong)], rawText: "\(wrong)")
    }
}

/// Encodes a candidate conformation into a task prompt and back.
public enum CandidateCodec {
    public static func encode(_ theta: [Double]) -> String {
        guard let data = try? JSONEncoder().encode(theta),
              let string = String(data: data, encoding: .utf8)
        else { return "[]" }
        return string
    }

    public static func decode(_ prompt: String) throws -> [Double] {
        guard let data = prompt.data(using: .utf8),
              let theta = try? JSONDecoder().decode([Double].self, from: data),
              !theta.isEmpty
        else { throw PilotError.badCandidate(prompt) }
        return theta
    }
}
