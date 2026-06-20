import CryptoKit
import Foundation

// Curve25519 Diffie–Hellman key agreement. Each node holds a key pair; any two nodes derive an
// identical shared seed from their own private key and the other's public key — without ever
// transmitting a secret. The shared secret is run through HKDF to produce the masking seed.

public enum PairwiseKeyAgreement {
    private static let salt = Data("orchard/secagg/v1".utf8)

    public static func sharedSeed(
        myPrivate: Curve25519.KeyAgreement.PrivateKey,
        theirPublic: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let secret = try myPrivate.sharedSecretFromKeyAgreement(with: theirPublic)
        return secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data(),
            outputByteCount: 32
        )
    }
}
