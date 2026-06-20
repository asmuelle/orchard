import CryptoKit
import Foundation
@testable import OrchardCrypto
import Testing

struct SecureAggregatorTests {
    private func seed(_ byte: UInt8) -> SymmetricKey {
        SymmetricKey(data: Data(repeating: byte, count: 32))
    }

    @Test("Pairwise masks cancel for two parties, recovering the plaintext sum")
    func masksCancelForTwoParties() {
        let shared = seed(9)
        let x0: [UInt32] = [10, 20, 30]
        let x1: [UInt32] = [1, 2, 3]

        let y0 = SecureAggregator.mask(vector: x0, partyIndex: 0, peers: [PeerSeed(index: 1, seed: shared)])
        let y1 = SecureAggregator.mask(vector: x1, partyIndex: 1, peers: [PeerSeed(index: 0, seed: shared)])

        #expect(SecureAggregator.aggregate([y0, y1], length: 3) == [11, 22, 33])
        #expect(y0 != x0) // the masked vector hides the plaintext
    }

    @Test("Pairwise masks cancel for three parties")
    func masksCancelForThreeParties() {
        let s01 = seed(1)
        let s02 = seed(2)
        let s12 = seed(3)
        let xs: [[UInt32]] = [[5, 5], [6, 6], [7, 7]]

        let y0 = SecureAggregator.mask(
            vector: xs[0], partyIndex: 0,
            peers: [PeerSeed(index: 1, seed: s01), PeerSeed(index: 2, seed: s02)]
        )
        let y1 = SecureAggregator.mask(
            vector: xs[1], partyIndex: 1,
            peers: [PeerSeed(index: 0, seed: s01), PeerSeed(index: 2, seed: s12)]
        )
        let y2 = SecureAggregator.mask(
            vector: xs[2], partyIndex: 2,
            peers: [PeerSeed(index: 0, seed: s02), PeerSeed(index: 1, seed: s12)]
        )

        #expect(SecureAggregator.aggregate([y0, y1, y2], length: 2) == [18, 18])
    }
}
