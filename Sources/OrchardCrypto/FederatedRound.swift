import CryptoKit
import Foundation

// Orchestrates one federated round end to end, as the system would: each participant clips and
// noises its gradient locally, quantizes, and masks; the server sums the masked vectors and
// recovers the mean. The server only ever sees masked vectors, yet the returned aggregate equals
// the differentially-private mean — demonstrating SecAgg's core property in one call.

public struct FederatedConfig: Sendable {
    public var clipNorm: Double
    public var noiseSigma: Double
    public var quantizationScale: Double

    public init(
        clipNorm: Double = 1.0,
        noiseSigma: Double = 0.0,
        quantizationScale: Double = 1_000_000
    ) {
        self.clipNorm = clipNorm
        self.noiseSigma = noiseSigma
        self.quantizationScale = quantizationScale
    }
}

public enum FederatedRound {
    /// Returns the secure, differentially-private mean of `gradients`, computed only from masked
    /// vectors. All gradients must share a length.
    public static func secureMean(
        gradients: [[Double]],
        config: FederatedConfig,
        using rng: inout some RandomNumberGenerator
    ) throws -> [Double] {
        let partyCount = gradients.count
        guard partyCount > 0 else { return [] }
        let length = gradients[0].count

        let quantizer = Quantizer(scale: config.quantizationScale)
        let dp = DifferentialPrivacy()

        // Each participant generates a key pair; public keys are exchanged.
        let privateKeys = (0 ..< partyCount).map { _ in Curve25519.KeyAgreement.PrivateKey() }
        let publicKeys = privateKeys.map(\.publicKey)

        // Local privatization + masking, per participant.
        var maskedVectors: [[UInt32]] = []
        maskedVectors.reserveCapacity(partyCount)

        for i in 0 ..< partyCount {
            var local = dp.clip(gradients[i], maxL2Norm: config.clipNorm)
            if config.noiseSigma > 0 {
                local = dp.addGaussianNoise(local, sigma: config.noiseSigma, using: &rng)
            }
            let encoded = quantizer.encode(local)

            var peers: [PeerSeed] = []
            peers.reserveCapacity(partyCount - 1)
            for j in 0 ..< partyCount where j != i {
                let seed = try PairwiseKeyAgreement.sharedSeed(
                    myPrivate: privateKeys[i],
                    theirPublic: publicKeys[j]
                )
                peers.append(PeerSeed(index: j, seed: seed))
            }
            maskedVectors.append(SecureAggregator.mask(vector: encoded, partyIndex: i, peers: peers))
        }

        // Server: sum masked vectors (masks cancel) → decode → divide by N.
        let summed = SecureAggregator.aggregate(maskedVectors, length: length)
        return quantizer.decodeSum(summed).map { $0 / Double(partyCount) }
    }
}
