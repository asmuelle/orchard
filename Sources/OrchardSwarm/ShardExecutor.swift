import Foundation

// The execution seam for micro-swarms. ShardPlanner decides *which* layers each device owns;
// a ShardExecutor actually *runs* them. The model is a stack of square Linear+tanh layers, so
// contiguous layer ranges compose cleanly across pipeline stages — activations flow device to
// device while weights stay put. The default executor is pure Swift (CI-safe); OrchardMLX
// provides a Metal-accelerated one with identical semantics.

public struct LayerWeights: Sendable, Hashable {
    /// Row-major `dimension × dimension` weight matrix.
    public let weight: [Float]
    /// Length-`dimension` bias vector.
    public let bias: [Float]

    public init(weight: [Float], bias: [Float]) {
        self.weight = weight
        self.bias = bias
    }
}

public struct ShardableModel: Sendable {
    public let dimension: Int
    public let layers: [LayerWeights]

    public init(dimension: Int, layers: [LayerWeights]) {
        self.dimension = dimension
        self.layers = layers
    }

    public var layerCount: Int {
        layers.count
    }
}

public enum ShardExecutorError: Error, Sendable, Hashable {
    case dimensionMismatch(expected: Int, actual: Int)
}

public protocol ShardExecutor: Sendable {
    /// Applies `model`'s layers in `layerRange` to `input` activations, returning the output
    /// activations for the next pipeline stage.
    func execute(
        layerRange: Range<Int>,
        of model: ShardableModel,
        input: [Float]
    ) async throws -> [Float]
}
