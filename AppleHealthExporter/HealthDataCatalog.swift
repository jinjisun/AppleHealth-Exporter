import Foundation
import HealthKit

/// HealthKit 可读指标目录（仅包含各版本 SDK 稳定支持的类型）。
enum HealthDataCatalog {
    enum MetricKind {
        case quantity(HKQuantityTypeIdentifier)
        case category(HKCategoryTypeIdentifier)
        case workout
        case characteristic
    }

    struct MetricDefinition {
        let exportKey: String
        let displayName: String
        let kind: MetricKind
        let unitLabel: String
        let hkUnit: HKUnit?
    }

    static var allMetrics: [MetricDefinition] {
        quantityMetrics + categoryMetrics + workoutMetric + characteristicMetric
    }

    static var exportableTypeCount: Int {
        allMetrics.count
    }

    static var objectTypesForAuthorization: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        for metric in allMetrics {
            switch metric.kind {
            case .quantity(let id):
                if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
            case .category(let id):
                if let t = HKObjectType.categoryType(forIdentifier: id) { types.insert(t) }
            case .workout:
                types.insert(HKObjectType.workoutType())
            case .characteristic:
                break
            }
        }
        return types
    }

    private static let quantityMetrics: [MetricDefinition] = [
        q("steps", "步数", .stepCount, "count", .count()),
        q("distance_walking_running", "步行跑步距离", .distanceWalkingRunning, "m", .meter()),
        q("distance_cycling", "骑行距离", .distanceCycling, "m", .meter()),
        q("flights_climbed", "爬楼层数", .flightsClimbed, "count", .count()),
        q("active_energy", "活动能量", .activeEnergyBurned, "kcal", .kilocalorie()),
        q("basal_energy", "基础代谢", .basalEnergyBurned, "kcal", .kilocalorie()),
        q("exercise_time", "锻炼时长", .appleExerciseTime, "min", .minute()),
        q("stand_time", "站立时长", .appleStandTime, "min", .minute()),
        q("heart_rate", "心率", .heartRate, "bpm", HKUnit.count().unitDivided(by: .minute())),
        q("resting_heart_rate", "静息心率", .restingHeartRate, "bpm", HKUnit.count().unitDivided(by: .minute())),
        q("walking_heart_rate_avg", "步行平均心率", .walkingHeartRateAverage, "bpm", HKUnit.count().unitDivided(by: .minute())),
        q("hrv_sdnn", "心率变异性", .heartRateVariabilitySDNN, "ms", .secondUnit(with: .milli)),
        q("vo2_max", "最大摄氧量", .vo2Max, "mL/kg·min", HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo)).unitDivided(by: .minute())),
        q("oxygen_saturation", "血氧", .oxygenSaturation, "%", .percent()),
        q("respiratory_rate", "呼吸频率", .respiratoryRate, "count/min", HKUnit.count().unitDivided(by: .minute())),
        q("height", "身高", .height, "m", .meter()),
        q("body_mass", "体重", .bodyMass, "kg", .gramUnit(with: .kilo)),
        q("bmi", "BMI", .bodyMassIndex, "kg/m²", .count()),
        q("body_fat_percentage", "体脂率", .bodyFatPercentage, "%", .percent()),
        q("lean_body_mass", "去脂体重", .leanBodyMass, "kg", .gramUnit(with: .kilo)),
        q("blood_pressure_systolic", "收缩压", .bloodPressureSystolic, "mmHg", .millimeterOfMercury()),
        q("blood_pressure_diastolic", "舒张压", .bloodPressureDiastolic, "mmHg", .millimeterOfMercury()),
        q("blood_glucose", "血糖", .bloodGlucose, "mg/dL", HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))),
        q("body_temperature", "体温", .bodyTemperature, "°C", .degreeCelsius()),
        q("environmental_audio_exposure", "环境音量", .environmentalAudioExposure, "dBASPL", .decibelAWeightedSoundPressureLevel()),
        q("headphone_audio_exposure", "耳机音量", .headphoneAudioExposure, "dBASPL", .decibelAWeightedSoundPressureLevel()),
        q("dietary_energy", "膳食能量", .dietaryEnergyConsumed, "kcal", .kilocalorie()),
        q("dietary_protein", "蛋白质", .dietaryProtein, "g", .gram()),
        q("dietary_carbs", "碳水化合物", .dietaryCarbohydrates, "g", .gram()),
        q("dietary_fat", "脂肪", .dietaryFatTotal, "g", .gram()),
        q("dietary_water", "饮水", .dietaryWater, "mL", .literUnit(with: .milli)),
        q("dietary_caffeine", "咖啡因", .dietaryCaffeine, "mg", .gramUnit(with: .milli)),
    ]

    private static let categoryMetrics: [MetricDefinition] = [
        c("sleep_analysis", "睡眠分析", .sleepAnalysis),
        c("mindful_session", "正念", .mindfulSession),
        c("stand_hour", "站立小时", .appleStandHour),
        c("menstrual_flow", "月经", .menstrualFlow),
        c("high_heart_rate", "高心率事件", .highHeartRateEvent),
        c("low_heart_rate", "低心率事件", .lowHeartRateEvent),
    ]

    private static let workoutMetric: [MetricDefinition] = [
        MetricDefinition(exportKey: "workout", displayName: "健身记录", kind: .workout, unitLabel: "session", hkUnit: nil),
    ]

    private static let characteristicMetric: [MetricDefinition] = [
        MetricDefinition(exportKey: "profile", displayName: "用户特征", kind: .characteristic, unitLabel: "profile", hkUnit: nil),
    ]

    private static func q(
        _ key: String,
        _ name: String,
        _ id: HKQuantityTypeIdentifier,
        _ unitLabel: String,
        _ unit: HKUnit
    ) -> MetricDefinition {
        MetricDefinition(exportKey: key, displayName: name, kind: .quantity(id), unitLabel: unitLabel, hkUnit: unit)
    }

    private static func c(
        _ key: String,
        _ name: String,
        _ id: HKCategoryTypeIdentifier
    ) -> MetricDefinition {
        MetricDefinition(exportKey: key, displayName: name, kind: .category(id), unitLabel: "category", hkUnit: nil)
    }
}
