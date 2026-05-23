import Combine
import Foundation
import HealthKit

struct HealthRecordPayload: Codable {
    let syncedAt: String
    let scope: String
    let metric: String?
    let batch: Int?
    let batchTotal: Int?
    let records: [HealthRecord]

    enum CodingKeys: String, CodingKey {
        case syncedAt = "synced_at"
        case scope, metric, batch
        case batchTotal = "batch_total"
        case records
    }
}

struct HealthRecord: Codable {
    let type: String
    let value: String
    let unit: String
    let startDate: String
    let endDate: String
    let source: String
    let metadata: String?

    enum CodingKeys: String, CodingKey {
        case type, value, unit
        case startDate = "start_date"
        case endDate = "end_date"
        case source, metadata
    }
}

final class HealthKitManager: ObservableObject {
    @Published var progress: Double = 0
    @Published var statusMessage = "就绪"
    @Published var isSyncing = false

    private let healthStore = HKHealthStore()
    private let uploadChunkSize = 2500

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var exportTypeCount: Int {
        HealthDataCatalog.exportableTypeCount
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    @MainActor
    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw SyncError.healthKitUnavailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: HealthDataCatalog.objectTypesForAuthorization)
    }

    @MainActor
    func syncAll(to host: String) async throws {
        guard isHealthDataAvailable else {
            throw SyncError.healthKitUnavailable
        }

        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SyncError.invalidHost
        }

        let base = trimmed.hasPrefix("http") ? trimmed : "http://\(trimmed):5000"
        guard let endpoint = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/health") else {
            throw SyncError.invalidHost
        }

        isSyncing = true
        progress = 0
        statusMessage = "正在请求 HealthKit 权限（\(exportTypeCount) 类指标）…"
        defer { isSyncing = false }

        try await requestAuthorization()

        let todayPredicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        let scopes: [(name: String, predicate: NSPredicate?)] = [
            ("all_history", nil),
            ("today", todayPredicate),
        ]

        var totalRecords = 0
        let syncMetrics = HealthDataCatalog.allMetrics.filter {
            if case .characteristic = $0.kind { return false }
            return true
        }
        let stepsPerScope = syncMetrics.count + 1

        for (scopeIndex, scope) in scopes.enumerated() {
            var scopeCount = 0
            statusMessage = scope.name == "all_history" ? "正在导出全部历史…" : "正在导出今日数据…"

            for (metricIndex, metric) in syncMetrics.enumerated() {
                let step = scopeIndex * stepsPerScope + metricIndex
                let overall = Double(step) / Double(scopes.count * stepsPerScope)
                progress = min(0.98, overall)

                statusMessage = "正在读取 \(metric.displayName)…"
                let records = try await fetchRecords(for: metric, predicate: scope.predicate)
                scopeCount += records.count

                if !records.isEmpty {
                    statusMessage = "正在上传 \(metric.displayName)（\(records.count) 条）…"
                    try await uploadInChunks(
                        records: records,
                        scope: scope.name,
                        metricKey: metric.exportKey,
                        endpoint: endpoint
                    )
                }

                progress = min(0.98, Double(step + 1) / Double(scopes.count * stepsPerScope))
            }

            if scope.name == "all_history" {
                let profile = fetchCharacteristicRecords()
                if !profile.isEmpty {
                    statusMessage = "正在上传用户特征…"
                    try await uploadInChunks(records: profile, scope: scope.name, metricKey: "profile", endpoint: endpoint)
                    scopeCount += profile.count
                }
            }

            totalRecords += scopeCount
        }

        progress = 1.0
        statusMessage = "同步完成 · 共 \(totalRecords) 条 · \(exportTypeCount) 类指标"
    }

    // MARK: - Fetch

    private nonisolated func resumeContinuation<T>(
        _ continuation: CheckedContinuation<T, Error>,
        error: Error?,
        samples: T
    ) {
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: samples)
        }
    }

    private func fetchRecords(for metric: HealthDataCatalog.MetricDefinition, predicate: NSPredicate?) async throws -> [HealthRecord] {
        switch metric.kind {
        case .quantity(let id):
            guard let type = HKQuantityType.quantityType(forIdentifier: id),
                  let unit = metric.hkUnit else { return [] }
            let samples = try await fetchQuantitySamples(type: type, predicate: predicate)
            return samples.map { quantityToRecord(sample: $0, exportKey: metric.exportKey, unit: unit, unitLabel: metric.unitLabel) }
        case .category(let id):
            guard let type = HKCategoryType.categoryType(forIdentifier: id) else { return [] }
            let samples = try await fetchCategorySamples(type: type, predicate: predicate)
            return samples.map { categoryToRecord(sample: $0, exportKey: metric.exportKey) }
        case .workout:
            let workouts = try await fetchWorkouts(predicate: predicate)
            return workouts.map { workoutToRecord($0) }
        case .characteristic:
            return []
        }
    }

    private func fetchQuantitySamples(type: HKQuantityType, predicate: NSPredicate?) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                resumeContinuation(continuation, error: error, samples: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchCategorySamples(type: HKCategoryType, predicate: NSPredicate?) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                resumeContinuation(continuation, error: error, samples: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(predicate: NSPredicate?) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                resumeContinuation(continuation, error: error, samples: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchCharacteristicRecords() -> [HealthRecord] {
        var records: [HealthRecord] = []
        let now = isoFormatter.string(from: Date())

        if let dob = try? healthStore.dateOfBirthComponents() {
            let value = "\(dob.year ?? 0)-\(dob.month ?? 0)-\(dob.day ?? 0)"
            records.append(HealthRecord(
                type: "date_of_birth", value: value, unit: "date",
                startDate: now, endDate: now, source: "HealthKit", metadata: nil
            ))
        }

        let sex = healthStore.biologicalSex()
        if sex != .notSet {
            records.append(HealthRecord(
                type: "biological_sex", value: "\(sex.rawValue)", unit: "enum",
                startDate: now, endDate: now, source: "HealthKit", metadata: nil
            ))
        }

        let blood = healthStore.bloodType()
        if blood != .notSet {
            records.append(HealthRecord(
                type: "blood_type", value: "\(blood.rawValue)", unit: "enum",
                startDate: now, endDate: now, source: "HealthKit", metadata: nil
            ))
        }

        if #available(iOS 13.0, *) {
            let skin = healthStore.fitzpatrickSkinType()
            if skin != .notSet {
                records.append(HealthRecord(
                    type: "fitzpatrick_skin_type", value: "\(skin.rawValue)", unit: "enum",
                    startDate: now, endDate: now, source: "HealthKit", metadata: nil
                ))
            }
        }

        let wheelchair = healthStore.wheelchairUse()
        if wheelchair != .notSet {
            records.append(HealthRecord(
                type: "wheelchair_use", value: "\(wheelchair.rawValue)", unit: "enum",
                startDate: now, endDate: now, source: "HealthKit", metadata: nil
            ))
        }

        return records
    }

    // MARK: - Mapping

    private func quantityToRecord(
        sample: HKQuantitySample,
        exportKey: String,
        unit: HKUnit,
        unitLabel: String
    ) -> HealthRecord {
        let value = sample.quantity.doubleValue(for: unit)
        let formatted: String
        if unit == .count() || unitLabel == "count" {
            formatted = String(format: "%.0f", value)
        } else if unitLabel == "%" {
            formatted = String(format: "%.2f", value * 100)
        } else {
            formatted = String(format: "%.4f", value)
        }

        return HealthRecord(
            type: exportKey,
            value: formatted,
            unit: unitLabel,
            startDate: isoFormatter.string(from: sample.startDate),
            endDate: isoFormatter.string(from: sample.endDate),
            source: sample.sourceRevision.source.name,
            metadata: nil
        )
    }

    private func categoryToRecord(sample: HKCategorySample, exportKey: String) -> HealthRecord {
        HealthRecord(
            type: exportKey,
            value: categoryValueLabel(sample: sample),
            unit: "category",
            startDate: isoFormatter.string(from: sample.startDate),
            endDate: isoFormatter.string(from: sample.endDate),
            source: sample.sourceRevision.source.name,
            metadata: nil
        )
    }

    private func categoryValueLabel(sample: HKCategorySample) -> String {
        if sample.categoryType.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue {
            return sleepStageLabel(sample.value)
        }
        return "value_\(sample.value)"
    }

    private func sleepStageLabel(_ value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue: return "in_bed"
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
        case HKCategoryValueSleepAnalysis.asleep.rawValue: return "asleep"
        default:
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "asleep_unspecified"
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "asleep_core"
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "asleep_deep"
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "asleep_rem"
                default: break
                }
            }
            return "sleep_\(value)"
        }
    }

    private func workoutToRecord(_ workout: HKWorkout) -> HealthRecord {
        var meta: [String: String] = [
            "activity_type": "\(workout.workoutActivityType.rawValue)",
            "duration_seconds": String(format: "%.0f", workout.duration),
        ]
        if let energy = workout.totalEnergyBurned {
            meta["total_energy_kcal"] = String(format: "%.1f", energy.doubleValue(for: .kilocalorie()))
        }
        if let distance = workout.totalDistance {
            meta["total_distance_m"] = String(format: "%.1f", distance.doubleValue(for: .meter()))
        }
        let metaJSON = (try? JSONSerialization.data(withJSONObject: meta))
            .flatMap { String(data: $0, encoding: .utf8) }

        return HealthRecord(
            type: "workout",
            value: HKWorkoutActivityType.name(for: workout.workoutActivityType) ?? "activity_\(workout.workoutActivityType.rawValue)",
            unit: "session",
            startDate: isoFormatter.string(from: workout.startDate),
            endDate: isoFormatter.string(from: workout.endDate),
            source: workout.sourceRevision.source.name,
            metadata: metaJSON
        )
    }

    // MARK: - Upload

    private func uploadInChunks(
        records: [HealthRecord],
        scope: String,
        metricKey: String,
        endpoint: URL
    ) async throws {
        guard !records.isEmpty else { return }

        let chunks = stride(from: 0, to: records.count, by: uploadChunkSize).map {
            Array(records[$0..<min($0 + uploadChunkSize, records.count)])
        }
        let total = chunks.count

        for (index, chunk) in chunks.enumerated() {
            try await post(
                payload: HealthRecordPayload(
                    syncedAt: isoFormatter.string(from: Date()),
                    scope: scope,
                    metric: metricKey,
                    batch: index + 1,
                    batchTotal: total,
                    records: chunk
                ),
                to: endpoint
            )
        }
    }

    private func post(payload: HealthRecordPayload, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.uploadFailed
        }
    }

    enum SyncError: LocalizedError {
        case healthKitUnavailable
        case invalidHost
        case uploadFailed

        var errorDescription: String? {
            switch self {
            case .healthKitUnavailable: return "此设备不支持 HealthKit"
            case .invalidHost: return "请输入有效的电脑 IP 地址"
            case .uploadFailed: return "上传失败，请确认 Windows 服务器已启动且在同一局域网"
            }
        }
    }
}

// MARK: - Workout name helper

private extension HKWorkoutActivityType {
    static func name(for type: HKWorkoutActivityType) -> String? {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .hiking: return "hiking"
        case .traditionalStrengthTraining: return "strength_training"
        case .highIntensityIntervalTraining: return "hiit"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairs: return "stairs"
        default: return nil
        }
    }
}
