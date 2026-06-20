#if canImport(MLX)
    import Foundation
    import MLX
    import OrchardSwarm

    // Metal-accelerated ShardExecutor. Runs a shard's layers as MLX tensor ops on the Apple GPU /
    // unified memory — the production path for micro-swarm inference. Semantics match
    // LocalShardExecutor exactly (y = tanh(W·x + b) per layer), which the parity test enforces, so a
    // shard can run on whichever executor a device prefers without changing results.

    public struct MLXShardExecutor: ShardExecutor {
        /// Compute stream / device. Defaults to MLX's default (GPU on a configured app). Headless
        /// SwiftPM executables can't load MLX's Metal library, so the demo/tests pass `.cpu`.
        private let stream: StreamOrDevice

        public init(stream: StreamOrDevice = .default) {
            self.stream = stream
        }

        public func execute(
            layerRange: Range<Int>,
            of model: ShardableModel,
            input: [Float]
        ) async throws -> [Float] {
            let dimension = model.dimension
            guard input.count == dimension else {
                throw ShardExecutorError.dimensionMismatch(expected: dimension, actual: input.count)
            }

            var activations = MLXArray(input).reshaped([dimension, 1])
            for index in layerRange {
                let layer = model.layers[index]
                let weight = MLXArray(layer.weight).reshaped([dimension, dimension])
                let bias = MLXArray(layer.bias).reshaped([dimension, 1])
                let projected = MLX.matmul(weight, activations, stream: stream)
                activations = MLX.tanh(MLX.add(projected, bias, stream: stream), stream: stream)
            }

            let flattened = activations.reshaped([dimension])
            return flattened.asArray(Float.self)
        }
    }
#endif
