import Foundation
import Testing
@testable import Gymbros

@Suite("NonceGenerator")
struct NonceGeneratorTests {
    @Test func randomNonce_hasRequestedLength() {
        #expect(NonceGenerator.randomNonceString(length: 32).count == 32)
        #expect(NonceGenerator.randomNonceString(length: 8).count == 8)
    }

    @Test func randomNonce_usesOnlyAllowedCharset() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = NonceGenerator.randomNonceString(length: 128)
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test func randomNonce_isNotConstant() {
        #expect(NonceGenerator.randomNonceString() != NonceGenerator.randomNonceString())
    }

    @Test func sha256_matchesKnownVector() {
        // echo -n "abc" | shasum -a 256
        #expect(NonceGenerator.sha256("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func sha256_isHex64() {
        let hash = NonceGenerator.sha256(NonceGenerator.randomNonceString())
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) })
    }
}
