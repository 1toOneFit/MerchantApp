import Foundation
import Testing
@testable import MerchantCatalog

/// Bucketing for `product_card_density_v1` (Experiments.md § Assignment, D-73).
struct ExperimentAssignerTests {
    /// Expected buckets computed independently with Python's `hashlib` (2026-11-13):
    /// `int.from_bytes(sha256(b"product_card_density_v1:" + id).digest()[:8], "big") % 10000`.
    @Test(arguments: [
        (uuid(0), 9656, ExperimentVariant.treatment),
        (uuid(1), 2573, .control),
        (uuid(3), 5845, .treatment),
        (UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!, 3092, .control),
    ])
    func goldenBuckets(installationID: UUID, bucket: Int, variant: ExperimentVariant) {
        #expect(ExperimentAssigner.bucket(for: .productCardDensity, installationID: installationID) == bucket)
        #expect(ExperimentAssigner.variant(for: .productCardDensity, installationID: installationID) == variant)
    }

    @Test func boundaryBucketsSplitTheArms() {
        #expect(ExperimentAssigner.variant(forBucket: 0) == .control)
        #expect(ExperimentAssigner.variant(forBucket: 4_999) == .control)
        #expect(ExperimentAssigner.variant(forBucket: 5_000) == .treatment)
        #expect(ExperimentAssigner.variant(forBucket: 9_999) == .treatment)
    }

    /// 50 % ± 2 % over 10 000 synthetic ids (ImplementationPlan § S6). Python gives 4 930 control.
    @Test func distributionIsBalanced() {
        let control = (0..<10_000)
            .filter { ExperimentAssigner.variant(for: .productCardDensity, installationID: uuid($0)) == .control }
            .count
        #expect((4_800...5_200).contains(control))
    }

    @Test func experimentIDIsTheDocumentedName() {
        #expect(Experiment.productCardDensity.rawValue == "product_card_density_v1")
    }
}
