// Describes the structured output an edge agent must return for a task. The schema travels
// with the TaskSpec so every node knows the exact shape to produce, and the router can
// validate and aggregate millions of results deterministically.

public enum SchemaFieldType: String, Sendable, Hashable, Codable {
    case string
    case number
    case boolean
    case array
    case object
    case null
}

public struct SchemaField: Sendable, Hashable, Codable {
    public let name: String
    public let type: SchemaFieldType
    public let isRequired: Bool

    public init(name: String, type: SchemaFieldType, isRequired: Bool = true) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
    }
}

public struct StructuredSchema: Sendable, Hashable, Codable {
    public let fields: [SchemaField]

    public init(fields: [SchemaField]) {
        self.fields = fields
    }

    /// Convenience for the common "all required" case.
    public static func required(_ pairs: [(String, SchemaFieldType)]) -> StructuredSchema {
        StructuredSchema(fields: pairs.map { SchemaField(name: $0.0, type: $0.1) })
    }
}
