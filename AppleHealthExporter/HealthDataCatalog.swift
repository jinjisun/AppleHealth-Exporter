import Foundation
import HealthKit

/// 面向健康分析的主流 HealthKit 可读指标（设备无数据时自动跳过）。
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
        var list: [MetricDefinition] = []
        list.append(contentsOf: quantityMetrics)
        list.append(contentsOf: categoryMetrics)
        list.append(contentsOf: workoutMetric)
        list.append(contentsOf: characteristicMetric)
        if #available(iOS 16.0, *) {
            list.append(contentsOf: quantityMetricsIOS16)
            list.append(contentsOf: categoryMetricsIOS16)
        }
        if #available(iOS 17.0, *) {
            list.append(contentsOf: quantityMetricsIOS17)
            list.append(contentsOf: categoryMetricsIOS17)
        }
        return list
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

    // MARK: - Quantity (iOS 15+)

    private static let quantityMetrics: [MetricDefinition] = [
        q("steps", "步数", .stepCount, "count", .count()),
        q("distance_walking_running", "步行跑步距离", .distanceWalkingRunning, "m", .meter()),
        q("distance_cycling", "骑行距离", .distanceCycling, "m", .meter()),
        q("distance_swimming", "游泳距离", .distanceSwimming, "m", .meter()),
        q("flights_climbed", "爬楼层数", .flightsClimbed, "count", .count()),
        q("active_energy", "活动能量", .activeEnergyBurned, "kcal", .kilocalorie()),
        q("basal_energy", "基础代谢", .basalEnergyBurned, "kcal", .kilocalorie()),
        q("exercise_time", "锻炼时长", .appleExerciseTime, "min", .minute()),
        q("stand_time", "站立时长", .appleStandTime, "min", .minute()),
        q("swimming_strokes", "游泳划水", .swimmingStrokeCount, "count", .count()),
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
        q("waist_circumference", "腰围", .waistCircumference, "m", .meter()),
        q("blood_pressure_systolic", "收缩压", .bloodPressureSystolic, "mmHg", .millimeterOfMercury()),
        q("blood_pressure_diastolic", "舒张压", .bloodPressureDiastolic, "mmHg", .millimeterOfMercury()),
        q("blood_glucose", "血糖", .bloodGlucose, "mg/dL", HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))),
        q("body_temperature", "体温", .bodyTemperature, "°C", .degreeCelsius()),
        q("walking_speed", "步行速度", .walkingSpeed, "m/s", .meter().unitDivided(by: .second())),
        q("walking_step_length", "步幅", .walkingStepLength, "m", .meter()),
        q("walking_asymmetry", "步行不对称", .walkingAsymmetryPercentage, "%", .percent()),
        q("walking_double_support", "双足支撑", .walkingDoubleSupportPercentage, "%", .percent()),
        q("stair_ascent_speed", "上楼速度", .stairAscentSpeed, "m/s", .meter().unitDivided(by: .second())),
        q("stair_descent_speed", "下楼速度", .stairDescentSpeed, "m/s", .meter().unitDivided(by: .second())),
        q("six_minute_walk", "6分钟步行距离", .sixMinuteWalkTestDistance, "m", .meter()),
        q("environmental_audio_exposure", "环境音量", .environmentalAudioExposure, "dBASPL", .decibelAWeightedSoundPressureLevel()),
        q("headphone_audio_exposure", "耳机音量", .headphoneAudioExposure, "dBASPL", .decibelAWeightedSoundPressureLevel()),
        q("uv_exposure", "紫外线暴露", .uvExposure, "count", .count()),
        q("electrodermal_activity", "皮电活动", .electrodermalActivity, "S", .siemen()),
        q("peak_expiratory_flow", "呼气峰值流速", .peakExpiratoryFlowRate, "L/s", .liter().unitDivided(by: .second())),
        q("forced_vital_capacity", "用力肺活量", .forcedVitalCapacity, "L", .liter()),
        q("alcoholic_beverages", "酒精饮品数", .numberOfAlcoholicBeverages, "count", .count()),
        q("dietary_energy", "膳食能量", .dietaryEnergyConsumed, "kcal", .kilocalorie()),
        q("dietary_protein", "蛋白质", .dietaryProtein, "g", .gram()),
        q("dietary_carbs", "碳水化合物", .dietaryCarbohydrates, "g", .gram()),
        q("dietary_fat", "脂肪", .dietaryFatTotal, "g", .gram()),
        q("dietary_fiber", "膳食纤维", .dietaryFiber, "g", .gram()),
        q("dietary_sugar", "糖", .dietarySugar, "g", .gram()),
        q("dietary_sodium", "钠", .dietarySodium, "mg", .gramUnit(with: .milli)),
        q("dietary_water", "饮水", .dietaryWater, "mL", .literUnit(with: .milli)),
        q("dietary_caffeine", "咖啡因", .dietaryCaffeine, "mg", .gramUnit(with: .milli)),
    ]

    @available(iOS 16.0, *)
    private static let quantityMetricsIOS16: [MetricDefinition] = [
        q("wrist_temperature", "手腕温度", .appleSleepingWristTemperature, "°C", .degreeCelsius()),
        q("atrial_fibrillation_burden", "房颤负担", .atrialFibrillationBurden, "%", .percent()),
        q("running_power", "跑步功率", .runningPower, "W", HKUnit.internationalUnit(withSymbol: "W")),
        q("running_speed", "跑步速度", .runningSpeed, "m/s", .meter().unitDivided(by: .second())),
        q("running_stride_length", "跑步步幅", .runningStrideLength, "m", .meter()),
        q("cycling_speed", "骑行速度", .cyclingSpeed, "m/s", .meter().unitDivided(by: .second())),
        q("cycling_power", "骑行功率", .cyclingPower, "W", HKUnit.internationalUnit(withSymbol: "W")),
        q("cycling_cadence", "踏频", .cyclingCadence, "count/min", HKUnit.count().unitDivided(by: .minute())),
    ]

    @available(iOS 17.0, *)
    private static let quantityMetricsIOS17: [MetricDefinition] = [
        q("time_in_daylight", "日光时间", .timeInDaylight, "min", .minute()),
        q("physical_effort", "体力消耗", .physicalEffort, "score", .count()),
    ]

    // MARK: - Category (iOS 15+)

    private static let categoryMetrics: [MetricDefinition] = [
        c("sleep_analysis", "睡眠分析", .sleepAnalysis),
        c("mindful_session", "正念", .mindfulSession),
        c("stand_hour", "站立小时", .appleStandHour),
        c("low_cardio_fitness", "低有氧适能", .lowCardioFitnessEvent),
        c("high_heart_rate", "高心率事件", .highHeartRateEvent),
        c("low_heart_rate", "低心率事件", .lowHeartRateEvent),
        c("irregular_heart_rhythm", "心律不齐", .irregularHeartRhythmEvent),
        c("audio_exposure_event", "音量暴露", .audioExposureEvent),
        c("toothbrushing", "刷牙", .toothbrushingEvent),
        c("handwashing", "洗手", .handwashingEvent),
        c("menstrual_flow", "月经", .menstrualFlow),
        c("intermenstrual_bleeding", "间期出血", .intermenstrualBleeding),
        c("ovulation_test", "排卵试纸", .ovulationTestResult),
        c("cervical_mucus", "宫颈粘液", .cervicalMucusQuality),
        c("sexual_activity", "性生活", .sexualActivity),
        c("pregnancy_test", "孕检", .pregnancyTestResult),
        c("progesterone_test", "孕酮", .progesteroneTestResult),
        c("lactation", "哺乳", .lactation),
        c("contraceptive", "避孕", .contraceptive),
        c("abdominal_cramps", "腹痛", .abdominalCramps),
        c("bloating", "腹胀", .bloating),
        c("constipation", "便秘", .constipation),
        c("diarrhea", "腹泻", .diarrhea),
        c("nausea", "恶心", .nausea),
        c("vomiting", "呕吐", .vomiting),
        c("headache", "头痛", .headache),
        c("fatigue", "疲劳", .fatigue),
        c("fever", "发热", .fever),
        c("chills", "寒战", .chills),
        c("dizziness", "头晕", .dizziness),
        c("fainting", "昏厥", .fainting),
        c("chest_tightness", "胸闷", .chestTightnessOrPain),
        c("shortness_of_breath", "气短", .shortnessOfBreath),
        c("rapid_pounding_heartbeat", "心悸", .rapidPoundingOrFlutteringHeartbeat),
        c("skipped_heartbeat", "漏搏", .skippedHeartbeat),
        c("lower_back_pain", "腰痛", .lowerBackPain),
        c("memory_lapse", "记忆减退", .memoryLapse),
        c("loss_of_smell", "嗅觉丧失", .lossOfSmell),
        c("loss_of_taste", "味觉丧失", .lossOfTaste),
        c("runny_nose", "流鼻涕", .runnyNose),
        c("sore_throat", "喉咙痛", .soreThroat),
        c("sinus_congestion", "鼻窦充血", .sinusCongestion),
        c("breast_pain", "乳房胀痛", .breastPain),
        c("dry_skin", "皮肤干燥", .drySkin),
        c("hair_loss", "脱发", .hairLoss),
    ]

    @available(iOS 16.0, *)
    private static let categoryMetricsIOS16: [MetricDefinition] = [
        c("sleep_apnea_event", "睡眠呼吸暂停", .sleepApneaEvent),
    ]

    @available(iOS 17.0, *)
    private static let categoryMetricsIOS17: [MetricDefinition] = [
        c("sleep_changes", "睡眠变化", .sleepChanges),
        c("appetite_changes", "食欲变化", .appetiteChanges),
        c("mood_changes", "情绪变化", .moodChanges),
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
