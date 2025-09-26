import Foundation
import os

enum PerformanceMetrics {
    private static let subsystem = "com.quincy.Future---Life-Updates"
    private static let category = "Performance"

    static let logger = Logger(subsystem: subsystem, category: category)
    static let signposter = OSSignposter(subsystem: subsystem, category: category)

    @discardableResult
    static func trace(_ name: StaticString, metadata: [String: String] = [:]) -> PerformanceTrace {
        PerformanceTrace(name: name, metadata: metadata, signposter: signposter, logger: logger)
    }

    static func mark(_ name: StaticString, metadata: [String: String] = [:]) {
        if metadata.isEmpty {
            logger.log("\(name, privacy: .public)")
        } else {
            let message = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logger.log("\(name, privacy: .public) :: \(message, privacy: .public)")
        }
        signposter.emitEvent(name)
    }

    fileprivate static func metadataDescription(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        return metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
    }
}

final class PerformanceTrace {
    private let name: StaticString
    private let signposter: OSSignposter
    private let logger: Logger
    private let intervalState: OSSignpostIntervalState
    private let start: DispatchTime
    private let initialMetadata: [String: String]
    private var isEnded = false

    init(name: StaticString, metadata: [String: String], signposter: OSSignposter, logger: Logger) {
        self.name = name
        self.signposter = signposter
        self.logger = logger
        self.initialMetadata = metadata
        intervalState = signposter.beginInterval(name, id: signposter.makeSignpostID())
        self.start = DispatchTime.now()
    }

    func end(extraMetadata: [String: String] = [:]) {
        guard !isEnded else { return }
        isEnded = true
        let end = DispatchTime.now()
        let elapsedNanoseconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        let elapsedSeconds = Double(elapsedNanoseconds) / 1_000_000_000

        let combinedMetadata = initialMetadata.merging(extraMetadata) { _, new in new }
        let metadataDescription = PerformanceMetrics.metadataDescription(combinedMetadata)

    signposter.endInterval(name, intervalState)

        if combinedMetadata.isEmpty {
            logger.debug("\(self.name, privacy: .public) finished in \(elapsedSeconds, format: .fixed(precision: 3))s")
        } else {
            logger.debug("\(self.name, privacy: .public) finished in \(elapsedSeconds, format: .fixed(precision: 3))s :: \(metadataDescription, privacy: .public)")
        }
    }

    deinit {
        end()
    }
}
