import Foundation
@testable import OrchardProtocol
import Testing

struct JSONValueTests {
    @Test("A nested value round-trips through Codable")
    func roundTripsThroughCodable() throws {
        let value: JSONValue = .object([
            "title": .string("ANE"),
            "score": .number(0.5),
            "active": .boolean(true),
            "topics": .array([.string("ml"), .string("npu")]),
            "missing": .null,
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("fieldType reflects the underlying case")
    func fieldTypeReflectsCase() {
        #expect(JSONValue.string("x").fieldType == .string)
        #expect(JSONValue.number(1).fieldType == .number)
        #expect(JSONValue.boolean(true).fieldType == .boolean)
        #expect(JSONValue.array([]).fieldType == .array)
        #expect(JSONValue.object([:]).fieldType == .object)
        #expect(JSONValue.null.fieldType == .null)
    }

    @Test("Decodes a raw JSON object into typed values")
    func decodesRawJSONObject() throws {
        let json = #"{"a":"x","b":2,"c":[true,null]}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        #expect(decoded["a"] == .string("x"))
        #expect(decoded["b"] == .number(2))
        #expect(decoded["c"] == .array([.boolean(true), .null]))
    }
}
