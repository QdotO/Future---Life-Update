import Foundation

struct BackupMergeService {

    struct MergeConflictReport: Codable {
        let timestamp: Date
        let conflicts: [Conflict]
        let summary: MergeSummary

        struct Conflict: Codable {
            let type: ConflictType
            let goalID: UUID
            let goalTitle: String
            let field: String
            let primaryValue: String
            let secondaryValue: String
            let recommendation: String

            enum ConflictType: String, Codable {
                case goalMetadata
                case questionDivergence
                case dataPointCollision
            }
        }

        struct MergeSummary: Codable {
            let totalConflicts: Int
            let goalConflicts: Int
            let questionConflicts: Int
            let dataPointConflicts: Int
            let canProceedWithoutConflictingData: Bool
        }
    }

    struct MergeResult {
        let merged: BackupPayload?
        let conflicts: MergeConflictReport?
        let success: Bool

        var hasConflicts: Bool {
            conflicts != nil && (conflicts?.conflicts.isEmpty == false)
        }
    }

    enum MergeStrategy {
        case stopOnConflict
        case skipConflicting
    }

    /// Merge two backup payloads with conflict detection
    func mergeBackups(
        primary: BackupPayload,
        secondary: BackupPayload,
        strategy: MergeStrategy = .stopOnConflict
    ) -> MergeResult {
        var conflicts: [MergeConflictReport.Conflict] = []
        var mergedGoals: [BackupPayload.Goal] = []

        // Create lookup dictionaries
        let primaryGoalsByID = Dictionary(uniqueKeysWithValues: primary.goals.map { ($0.id, $0) })
        let secondaryGoalsByID = Dictionary(
            uniqueKeysWithValues: secondary.goals.map { ($0.id, $0) })

        let allGoalIDs = Set(primaryGoalsByID.keys).union(secondaryGoalsByID.keys)

        for goalID in allGoalIDs {
            let primaryGoal = primaryGoalsByID[goalID]
            let secondaryGoal = secondaryGoalsByID[goalID]

            if let primary = primaryGoal, let secondary = secondaryGoal {
                // Both backups have this goal - need to merge
                let (mergedGoal, goalConflicts) = mergeGoal(primary: primary, secondary: secondary)
                conflicts.append(contentsOf: goalConflicts)

                if strategy == .stopOnConflict && !goalConflicts.isEmpty {
                    // Stop immediately on conflict
                    continue
                }

                if strategy == .skipConflicting && !goalConflicts.isEmpty {
                    // Skip this goal entirely if it has conflicts
                    continue
                }

                mergedGoals.append(mergedGoal)
            } else if let primary = primaryGoal {
                // Only in primary
                mergedGoals.append(primary)
            } else if let secondary = secondaryGoal {
                // Only in secondary
                mergedGoals.append(secondary)
            }
        }

        if strategy == .stopOnConflict && !conflicts.isEmpty {
            // Return conflict report without merged data
            let conflictReport = MergeConflictReport(
                timestamp: Date(),
                conflicts: conflicts,
                summary: MergeConflictReport.MergeSummary(
                    totalConflicts: conflicts.count,
                    goalConflicts: conflicts.filter { $0.type == .goalMetadata }.count,
                    questionConflicts: conflicts.filter { $0.type == .questionDivergence }.count,
                    dataPointConflicts: conflicts.filter { $0.type == .dataPointCollision }.count,
                    canProceedWithoutConflictingData: true
                )
            )

            return MergeResult(merged: nil, conflicts: conflictReport, success: false)
        }

        // Build merged payload
        let mergedPayload = BackupPayload(
            version: max(primary.version, secondary.version),
            exportedAt: Date(),
            goals: mergedGoals.sorted { $0.createdAt < $1.createdAt }
        )

        let conflictReport =
            conflicts.isEmpty
            ? nil
            : MergeConflictReport(
                timestamp: Date(),
                conflicts: conflicts,
                summary: MergeConflictReport.MergeSummary(
                    totalConflicts: conflicts.count,
                    goalConflicts: conflicts.filter { $0.type == .goalMetadata }.count,
                    questionConflicts: conflicts.filter { $0.type == .questionDivergence }.count,
                    dataPointConflicts: conflicts.filter { $0.type == .dataPointCollision }.count,
                    canProceedWithoutConflictingData: strategy == .skipConflicting
                )
            )

        return MergeResult(merged: mergedPayload, conflicts: conflictReport, success: true)
    }

    private func mergeGoal(
        primary: BackupPayload.Goal,
        secondary: BackupPayload.Goal
    ) -> (BackupPayload.Goal, [MergeConflictReport.Conflict]) {
        var conflicts: [MergeConflictReport.Conflict] = []

        // Choose the goal with latest updatedAt
        let winner = primary.updatedAt > secondary.updatedAt ? primary : secondary

        // Check for metadata conflicts
        if primary.title != secondary.title {
            conflicts.append(
                MergeConflictReport.Conflict(
                    type: .goalMetadata,
                    goalID: primary.id,
                    goalTitle: winner.title,
                    field: "title",
                    primaryValue: primary.title,
                    secondaryValue: secondary.title,
                    recommendation: "Using '\(winner.title)' (most recent)"
                ))
        }

        if primary.goalDescription != secondary.goalDescription {
            conflicts.append(
                MergeConflictReport.Conflict(
                    type: .goalMetadata,
                    goalID: primary.id,
                    goalTitle: winner.title,
                    field: "description",
                    primaryValue: String(primary.goalDescription.prefix(50)),
                    secondaryValue: String(secondary.goalDescription.prefix(50)),
                    recommendation: "Using description from most recent version"
                ))
        }

        if primary.isActive != secondary.isActive {
            conflicts.append(
                MergeConflictReport.Conflict(
                    type: .goalMetadata,
                    goalID: primary.id,
                    goalTitle: winner.title,
                    field: "isActive",
                    primaryValue: String(primary.isActive),
                    secondaryValue: String(secondary.isActive),
                    recommendation: "Using '\(winner.isActive)' (most recent)"
                ))
        }

        // Merge questions
        let (mergedQuestions, questionConflicts) = mergeQuestions(
            primary: primary.questions,
            secondary: secondary.questions,
            goalID: primary.id,
            goalTitle: winner.title
        )
        conflicts.append(contentsOf: questionConflicts)

        // Merge data points
        let (mergedDataPoints, dataPointConflicts) = mergeDataPoints(
            primary: primary.dataPoints,
            secondary: secondary.dataPoints,
            goalID: primary.id,
            goalTitle: winner.title
        )
        conflicts.append(contentsOf: dataPointConflicts)

        // Build merged goal
        let mergedGoal = BackupPayload.Goal(
            id: primary.id,
            title: winner.title,
            goalDescription: winner.goalDescription,
            category: winner.category,
            customCategoryLabel: winner.customCategoryLabel,
            isActive: winner.isActive,
            createdAt: min(primary.createdAt, secondary.createdAt),
            updatedAt: max(primary.updatedAt, secondary.updatedAt),
            schedule: winner.schedule,
            questions: mergedQuestions,
            dataPoints: mergedDataPoints
        )

        return (mergedGoal, conflicts)
    }

    private func mergeQuestions(
        primary: [BackupPayload.Question],
        secondary: [BackupPayload.Question],
        goalID: UUID,
        goalTitle: String
    ) -> ([BackupPayload.Question], [MergeConflictReport.Conflict]) {
        var conflicts: [MergeConflictReport.Conflict] = []
        var merged: [UUID: BackupPayload.Question] = [:]

        // Add all primary questions
        for question in primary {
            merged[question.id] = question
        }

        // Merge secondary questions
        for secQuestion in secondary {
            if let primQuestion = merged[secQuestion.id] {
                // Question exists in both - check for conflicts
                if primQuestion.text != secQuestion.text {
                    conflicts.append(
                        MergeConflictReport.Conflict(
                            type: .questionDivergence,
                            goalID: goalID,
                            goalTitle: goalTitle,
                            field: "question.text",
                            primaryValue: primQuestion.text,
                            secondaryValue: secQuestion.text,
                            recommendation: "Manual resolution required"
                        ))
                }

                if primQuestion.responseType != secQuestion.responseType {
                    conflicts.append(
                        MergeConflictReport.Conflict(
                            type: .questionDivergence,
                            goalID: goalID,
                            goalTitle: goalTitle,
                            field: "question.responseType",
                            primaryValue: primQuestion.responseType.rawValue,
                            secondaryValue: secQuestion.responseType.rawValue,
                            recommendation: "Manual resolution required"
                        ))
                }
            } else {
                // Only in secondary - add it
                merged[secQuestion.id] = secQuestion
            }
        }

        return (Array(merged.values), conflicts)
    }

    private func mergeDataPoints(
        primary: [BackupPayload.DataPoint],
        secondary: [BackupPayload.DataPoint],
        goalID: UUID,
        goalTitle: String
    ) -> ([BackupPayload.DataPoint], [MergeConflictReport.Conflict]) {
        var conflicts: [MergeConflictReport.Conflict] = []
        var merged: [UUID: BackupPayload.DataPoint] = [:]

        // Add all primary data points
        for point in primary {
            merged[point.id] = point
        }

        // Merge secondary data points
        for secPoint in secondary {
            if let primPoint = merged[secPoint.id] {
                // Data point exists in both - check for collision
                if !dataPointsEqual(primPoint, secPoint) {
                    // Keep the one with newer timestamp
                    let winner = primPoint.timestamp > secPoint.timestamp ? primPoint : secPoint
                    merged[secPoint.id] = winner

                    conflicts.append(
                        MergeConflictReport.Conflict(
                            type: .dataPointCollision,
                            goalID: goalID,
                            goalTitle: goalTitle,
                            field: "dataPoint",
                            primaryValue: "timestamp: \(primPoint.timestamp)",
                            secondaryValue: "timestamp: \(secPoint.timestamp)",
                            recommendation: "Using entry with timestamp \(winner.timestamp)"
                        ))
                }
            } else {
                // Only in secondary - add it
                merged[secPoint.id] = secPoint
            }
        }

        return (Array(merged.values).sorted { $0.timestamp < $1.timestamp }, conflicts)
    }

    private func dataPointsEqual(_ lhs: BackupPayload.DataPoint, _ rhs: BackupPayload.DataPoint)
        -> Bool
    {
        return lhs.timestamp == rhs.timestamp && lhs.numericValue == rhs.numericValue
            && lhs.numericDelta == rhs.numericDelta && lhs.textValue == rhs.textValue
            && lhs.boolValue == rhs.boolValue && lhs.selectedOptions == rhs.selectedOptions
    }

    func exportConflictReport(_ report: MergeConflictReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }
}
