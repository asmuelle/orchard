// Fixed-point quantization into a UInt32 field. Secure Aggregation needs masks to cancel
// *exactly*, which floating point cannot guarantee — so gradients are encoded as two's-complement
// Int32 stored in UInt32, where wrapping addition is exact modular arithmetic. Decoding a summed
// field vector recovers the true integer sum as long as it stays within Int32 range.

public struct Quantizer: Sendable {
    public let scale: Double

    public init(scale: Double) {
        self.scale = scale
    }

    public func encode(_ values: [Double]) -> [UInt32] {
        values.map { value in
            let scaled = (value * scale).rounded()
            let clamped = min(max(scaled, Double(Int32.min)), Double(Int32.max))
            return UInt32(bitPattern: Int32(clamped))
        }
    }

    /// Decodes a field vector that holds a *sum* of encoded values back to Double.
    public func decodeSum(_ encoded: [UInt32]) -> [Double] {
        encoded.map { Double(Int32(bitPattern: $0)) / scale }
    }
}
