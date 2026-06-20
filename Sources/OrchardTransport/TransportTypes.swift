// Wire types and errors for cross-device activation transport. Activations (not weights) cross
// the network between pipeline stages: a request carries the layer range to run and the input
// activations; the response carries the output activations. Kept Codable so the framing layer can
// serialize them; deliberately small so they fit the "ship activations, not model weights" model.

public struct NodeEndpoint: Sendable, Hashable {
    public let host: String
    public let port: UInt16

    public init(host: String = "127.0.0.1", port: UInt16) {
        self.host = host
        self.port = port
    }
}

public struct ActivationRequest: Sendable, Codable {
    public let layerLowerBound: Int
    public let layerUpperBound: Int
    public let values: [Float]

    public var layerRange: Range<Int> {
        layerLowerBound ..< layerUpperBound
    }

    public init(layerRange: Range<Int>, values: [Float]) {
        layerLowerBound = layerRange.lowerBound
        layerUpperBound = layerRange.upperBound
        self.values = values
    }
}

public struct ActivationResponse: Sendable, Codable {
    public let values: [Float]?
    public let error: String?

    public init(values: [Float]?, error: String?) {
        self.values = values
        self.error = error
    }
}

public enum TransportError: Error, Sendable, Hashable {
    case invalidEndpoint(host: String, port: UInt16)
    case connectionClosed
    case malformedResponse
    case remote(String)
}
