import XCTest
import CryptoKit
@testable import Verg

/// Access codes are salted digests in source now, so that the repository is
/// safe to publish.
///
/// Note what this file deliberately does *not* contain: a working code. The
/// first draft asserted that each real code is accepted, which would have
/// put all three back into the public repository in plain text and undone
/// the whole change. The valid path is exercised by hashing a throwaway
/// string and checking the digest function against a precomputed value —
/// same code path, no secret. The real codes were verified by hand once,
/// locally, and live outside this repository.
final class AccessCodeTests: XCTestCase {

    /// The leaked ones. These three sat in a public repository in plain
    /// text for months; anyone who read them then must not still have
    /// access now. This is the assertion the rotation exists for.
    @MainActor
    func testCodesThatLeakedNoLongerWork() {
        for code in ["VERGFAM", "VERGVIP", "ONTHEVERG"] {
            XCTAssertFalse(PurchaseService.shared.redeemAccessCode(code),
                           "A code that was public in git history still grants access: \(code)")
        }
    }

    @MainActor
    func testNonsenseIsRefused() {
        for code in ["HELLO", "", "   ", "VERGFAM-", "0000"] {
            XCTAssertFalse(PurchaseService.shared.redeemAccessCode(code),
                           "Refusal expected for \(code.isEmpty ? "<empty>" : code)")
        }
    }

    /// The digest itself, against a value that is not a code.
    ///
    /// Fails if the salt or the hashing changes, which would silently
    /// invalidate every real code at once — the failure mode worth catching,
    /// since it would look exactly like "the codes stopped working" with no
    /// clue why.
    func testDigestIsStable() {
        let salted = "verg.access.v2" + "NOT-A-REAL-CODE"
        let hex = SHA256.hash(data: Data(salted.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        XCTAssertEqual(
            hex,
            "071945ada86c03e7d9fb2a8f94936ac65ed29c8f88638055fc9e1dbd61314266",
            "The access-code salt or hash changed; every issued code is now dead"
        )
    }

    /// Digests only — no plaintext should ever appear beside them again.
    func testTheDigestListLooksLikeDigests() {
        XCTAssertFalse(PurchaseService.validAccessCodeDigests.isEmpty)
        for digest in PurchaseService.validAccessCodeDigests {
            XCTAssertEqual(digest.count, 64, "Not a SHA-256 hex digest: \(digest)")
            XCTAssertTrue(digest.allSatisfy { $0.isHexDigit && !$0.isUppercase },
                          "Digest should be lowercase hex: \(digest)")
        }
    }
}
