// Boundary validation. Every structured payload returned by a node is checked against the
// task's schema before it is trusted or aggregated. Fail fast, with a precise reason.

public enum ProtocolError: Error, Sendable, Hashable {
    case emptyPrompt
    case invalidRedundancy(Int)
    case missingField(String)
    case typeMismatch(field: String, expected: SchemaFieldType, actual: SchemaFieldType)
}

public enum SchemaValidator {
    /// Validates a payload against a schema. Required fields must be present with the declared
    /// type; optional fields, when present, must match their type. Unknown extra keys are allowed.
    public static func validate(
        _ payload: [String: JSONValue],
        against schema: StructuredSchema
    ) throws {
        for field in schema.fields {
            guard let value = payload[field.name] else {
                if field.isRequired {
                    throw ProtocolError.missingField(field.name)
                }
                continue
            }
            // A null value satisfies an optional field but not a required typed one.
            if case .null = value, !field.isRequired {
                continue
            }
            guard value.fieldType == field.type else {
                throw ProtocolError.typeMismatch(
                    field: field.name,
                    expected: field.type,
                    actual: value.fieldType
                )
            }
        }
    }
}
