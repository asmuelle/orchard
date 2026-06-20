import CryptoKit
import Foundation
@testable import OrchardCrypto
import Testing

struct MaskGeneratorTests {
    @Test("The same seed produces the same keystream")
    func deterministicForSameSeed() {
        let seed = SymmetricKey(data: Data(repeating: 7, count: 32))
        #expect(MaskGenerator.stream(seed: seed, count: 20) == MaskGenerator.stream(seed: seed, count: 20))
    }

    @Test("Different seeds produce different keystreams")
    func differsForDifferentSeeds() {
        let a = SymmetricKey(data: Data(repeating: 1, count: 32))
        let b = SymmetricKey(data: Data(repeating: 2, count: 32))
        #expect(MaskGenerator.stream(seed: a, count: 16) != MaskGenerator.stream(seed: b, count: 16))
    }

    @Test("Produces exactly the requested number of words")
    func respectsCount() {
        let seed = SymmetricKey(data: Data(repeating: 3, count: 32))
        #expect(MaskGenerator.stream(seed: seed, count: 0).isEmpty)
        #expect(MaskGenerator.stream(seed: seed, count: 13).count == 13)
    }
}
