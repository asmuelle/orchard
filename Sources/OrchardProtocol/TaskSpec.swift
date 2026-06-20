// A single unit of work the Task Router fragments out to the swarm. Deliberately tiny: a
// prompt plus the structured-output schema the node must satisfy. `redundancy` is how many
// independent nodes should run it so results can be cross-checked by consensus.

public enum TaskKind: String, Sendable, Hashable, Codable {
    /// Read and summarize a chunk of public web content into structured fields.
    case index
    /// Run a fragment of a scientific simulation / model evaluation.
    case simulate
    /// General structured-output inference.
    case infer
}

public struct TaskSpec: Sendable, Hashable, Codable, Identifiable {
    public let id: TaskID
    public let kind: TaskKind
    public let prompt: String
    public let outputSchema: StructuredSchema
    public let redundancy: Int

    /// Creates a task, validating its invariants. Throws ``ProtocolError`` on bad input so
    /// malformed work is rejected at the boundary rather than failing deep in a node.
    public init(
        id: TaskID,
        kind: TaskKind,
        prompt: String,
        outputSchema: StructuredSchema,
        redundancy: Int = 1
    ) throws {
        guard prompt.contains(where: { !$0.isWhitespace }) else { throw ProtocolError.emptyPrompt }
        guard redundancy >= 1 else { throw ProtocolError.invalidRedundancy(redundancy) }
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.outputSchema = outputSchema
        self.redundancy = redundancy
    }
}
