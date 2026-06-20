import CryptoKit

// Pairwise-additive Secure Aggregation (Bonawitz et al.). Each party masks its vector with the
// sum of pairwise PRG streams: +stream for higher-indexed peers, −stream for lower-indexed peers.
// Every pair's mask therefore appears once with each sign across the fleet, so the server's sum
// of masked vectors equals the plaintext sum — while no individual masked vector reveals anything.

public struct PeerSeed: Sendable {
    public let index: Int
    public let seed: SymmetricKey

    public init(index: Int, seed: SymmetricKey) {
        self.index = index
        self.seed = seed
    }
}

public enum SecureAggregator {
    /// Masks one party's encoded vector against all of its peers.
    public static func mask(
        vector: [UInt32],
        partyIndex: Int,
        peers: [PeerSeed]
    ) -> [UInt32] {
        var masked = vector
        for peer in peers {
            let stream = MaskGenerator.stream(seed: peer.seed, count: vector.count)
            if peer.index > partyIndex {
                for k in masked.indices {
                    masked[k] = masked[k] &+ stream[k]
                }
            } else {
                for k in masked.indices {
                    masked[k] = masked[k] &- stream[k]
                }
            }
        }
        return masked
    }

    /// The server step: element-wise wrapping sum. Masks cancel, leaving the plaintext sum.
    public static func aggregate(_ maskedVectors: [[UInt32]], length: Int) -> [UInt32] {
        var sum = [UInt32](repeating: 0, count: length)
        for vector in maskedVectors {
            let n = min(length, vector.count)
            for k in 0 ..< n {
                sum[k] = sum[k] &+ vector[k]
            }
        }
        return sum
    }
}
