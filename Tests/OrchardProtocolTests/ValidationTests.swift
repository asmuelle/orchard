@testable import OrchardProtocol
import Testing

struct ValidationTests {
    let schema = StructuredSchema.required([
        ("title", .string),
        ("score", .number),
    ])

    @Test("Valid payload passes validation")
    func validPayloadPasses() throws {
        let payload: [String: JSONValue] = [
            "title": .string("ANE"),
            "score": .number(0.9),
        ]
        try SchemaValidator.validate(payload, against: schema)
    }

    @Test("Missing required field throws")
    func missingRequiredFieldThrows() {
        let payload: [String: JSONValue] = ["title": .string("ANE")]
        #expect(throws: ProtocolError.missingField("score")) {
            try SchemaValidator.validate(payload, against: schema)
        }
    }

    @Test("Type mismatch throws a precise error")
    func typeMismatchThrows() {
        let payload: [String: JSONValue] = [
            "title": .string("ANE"),
            "score": .string("high"),
        ]
        #expect(throws: ProtocolError.typeMismatch(field: "score", expected: .number, actual: .string)) {
            try SchemaValidator.validate(payload, against: schema)
        }
    }

    @Test("Unknown extra keys are allowed")
    func extraKeysAllowed() throws {
        let payload: [String: JSONValue] = [
            "title": .string("ANE"),
            "score": .number(1),
            "extra": .boolean(true),
        ]
        try SchemaValidator.validate(payload, against: schema)
    }

    @Test("Optional field may be absent or null")
    func optionalFieldMayBeAbsentOrNull() throws {
        let optionalSchema = StructuredSchema(fields: [
            SchemaField(name: "note", type: .string, isRequired: false),
        ])
        try SchemaValidator.validate([:], against: optionalSchema)
        try SchemaValidator.validate(["note": .null], against: optionalSchema)
    }
}
