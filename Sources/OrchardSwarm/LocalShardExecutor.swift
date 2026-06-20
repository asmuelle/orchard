import Foundation

// Pure-Swift reference executor. Runs the real forward pass for a shard's layers on the CPU:
// y = tanh(W·x + b) per layer. Dependency-free, so it builds and runs anywhere (CI included) and
// serves as the correctness oracle the MLX executor is checked against.

public struct LocalShardExecutor: ShardExecutor {
    public init() {}

    public func execute(
        layerRange: Range<Int>,
        of model: ShardableModel,
        input: [Float]
    ) async throws -> [Float] {
        guard input.count == model.dimension else {
            throw ShardExecutorError.dimensionMismatch(expected: model.dimension, actual: input.count)
        }
        var activations = input
        for index in layerRange {
            activations = Self.forward(model.layers[index], input: activations, dimension: model.dimension)
        }
        return activations
    }

    /// One layer: tanh(W·x + b).
    static func forward(_ layer: LayerWeights, input: [Float], dimension: Int) -> [Float] {
        var output = [Float](repeating: 0, count: dimension)
        for row in 0 ..< dimension {
            var accumulator = layer.bias[row]
            let base = row * dimension
            for column in 0 ..< dimension {
                accumulator += layer.weight[base + column] * input[column]
            }
            output[row] = Float(tanh(Double(accumulator)))
        }
        return output
    }
}
