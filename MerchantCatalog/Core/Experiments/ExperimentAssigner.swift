import CryptoKit
import Foundation

/// Stable bucketing (Experiments.md § Assignment): the first 8 bytes of
/// `SHA-256("<experiment_id>:<installation_id>")`, read big-endian as a `UInt64`, modulo 10 000;
/// buckets below 5 000 are `control`. The installation id is `UUID.uuidString`, the uppercase form
/// the analytics envelope sends (D-73). Swift's `hashValue` is not used: it is seeded per process.
enum ExperimentAssigner {
    static let bucketCount = 10_000
    /// 50 % control, 50 % treatment.
    static let controlBuckets = 5_000

    static func bucket(for experiment: Experiment, installationID: UUID) -> Int {
        let input = Data("\(experiment.rawValue):\(installationID.uuidString)".utf8)
        let prefix = SHA256.hash(data: input).prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Int(prefix % UInt64(bucketCount))
    }

    static func variant(for experiment: Experiment, installationID: UUID) -> ExperimentVariant {
        variant(forBucket: bucket(for: experiment, installationID: installationID))
    }

    static func variant(forBucket bucket: Int) -> ExperimentVariant {
        bucket < controlBuckets ? .control : .treatment
    }
}
