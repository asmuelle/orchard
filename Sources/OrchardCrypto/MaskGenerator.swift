import CryptoKit
import Foundation

// Deterministic pseudo-random generator that expands a shared seed into a UInt32 keystream. Both
// peers in a pair derive the same seed (via key agreement) and therefore the same mask, which is
// what lets pairwise masks cancel on the server. Implemented as HMAC-SHA256 in counter mode — a
// standard, vetted PRG construction.

public enum MaskGenerator {
    public static func stream(seed: SymmetricKey, count: Int) -> [UInt32] {
        var output: [UInt32] = []
        output.reserveCapacity(count)

        var counter: UInt64 = 0
        while output.count < count {
            let message = withUnsafeBytes(of: counter.littleEndian) { Data($0) }
            let block = HMAC<SHA256>.authenticationCode(for: message, using: seed)
            let bytes = Array(block) // 32 bytes → 8 UInt32 words

            var index = 0
            while index + 4 <= bytes.count, output.count < count {
                let word = UInt32(bytes[index])
                    | UInt32(bytes[index + 1]) << 8
                    | UInt32(bytes[index + 2]) << 16
                    | UInt32(bytes[index + 3]) << 24
                output.append(word)
                index += 4
            }
            counter += 1
        }
        return output
    }
}
