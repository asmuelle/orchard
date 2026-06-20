import CryptoKit
@testable import OrchardCrypto
import Testing

struct KeyAgreementTests {
    @Test("Two parties derive the same shared seed from a key exchange")
    func sharedSeedIsSymmetric() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()

        let aliceSeed = try PairwiseKeyAgreement.sharedSeed(
            myPrivate: alice, theirPublic: bob.publicKey
        )
        let bobSeed = try PairwiseKeyAgreement.sharedSeed(
            myPrivate: bob, theirPublic: alice.publicKey
        )

        // Compare via the derived keystream — equal seeds ⇒ identical masks, which is what
        // makes pairwise cancellation work.
        #expect(MaskGenerator.stream(seed: aliceSeed, count: 8)
            == MaskGenerator.stream(seed: bobSeed, count: 8))
    }

    @Test("Unrelated key pairs derive different seeds")
    func unrelatedPartiesDiffer() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let eve = Curve25519.KeyAgreement.PrivateKey()

        let ab = try PairwiseKeyAgreement.sharedSeed(myPrivate: alice, theirPublic: bob.publicKey)
        let ae = try PairwiseKeyAgreement.sharedSeed(myPrivate: alice, theirPublic: eve.publicKey)

        #expect(MaskGenerator.stream(seed: ab, count: 8)
            != MaskGenerator.stream(seed: ae, count: 8))
    }
}
