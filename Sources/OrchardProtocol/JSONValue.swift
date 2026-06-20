// A minimal, Sendable JSON value used to carry structured task output across the wire
// without binding the protocol to any one concrete model. Edge agents produce these via
// the Apple Foundation Models structured-output ("@Generable") path; the router aggregates them.

public enum JSONValue: Sendable, Hashable, Codable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .boolean(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

public extension JSONValue {
    /// The runtime kind of this value, used for schema validation.
    var fieldType: SchemaFieldType {
        switch self {
        case .string: .string
        case .number: .number
        case .boolean: .boolean
        case .array: .array
        case .object: .object
        case .null: .null
        }
    }
}
