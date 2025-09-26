import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    private let backupManager: DataBackupManager
    private let modelContext: ModelContext
    private let filenameFormatter: DateFormatter

    init(modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.backupManager = DataBackupManager(modelContext: modelContext, dateProvider: dateProvider)
        self.filenameFormatter = SettingsViewModel.makeFilenameFormatter()
    }

    func makeDefaultFilename() -> String {
        let timestamp = filenameFormatter.string(from: Date())
        return "FutureLifeBackup-\(timestamp)"
    }

    func createBackupDocument() throws -> BackupDocument {
        try backupManager.makeBackupDocument()
    }

    func importBackup(from data: Data, replaceExisting: Bool = true) throws -> DataBackupManager.ImportSummary {
        try backupManager.importBackup(from: data, replaceExisting: replaceExisting)
    }

    func hasExistingData() throws -> Bool {
        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor).isEmpty == false
    }

    private static func makeFilenameFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }
}
