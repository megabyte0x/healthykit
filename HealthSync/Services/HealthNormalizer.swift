import Foundation

enum HealthDataType: String, CaseIterable, Codable, Identifiable, Equatable {
    case appleSleepingWristTemperature = "apple_sleeping_wrist_temperature"
    case bodyFatPercentage = "body_fat_percentage"
    case bodyMass = "body_mass"
    case bodyMassIndex = "body_mass_index"
    case electrodermalActivity = "electrodermal_activity"
    case height = "height"
    case leanBodyMass = "lean_body_mass"
    case waistCircumference = "waist_circumference"
    case activeEnergy = "active_energy"
    case appleExerciseTime = "apple_exercise_time"
    case appleMoveTime = "apple_move_time"
    case appleStandTime = "apple_stand_time"
    case basalEnergy = "basal_energy"
    case crossCountrySkiingSpeed = "cross_country_skiing_speed"
    case cyclingCadence = "cycling_cadence"
    case cyclingFunctionalThresholdPower = "cycling_functional_threshold_power"
    case cyclingPower = "cycling_power"
    case cyclingSpeed = "cycling_speed"
    case distanceCrossCountrySkiing = "distance_cross_country_skiing"
    case distanceCycling = "distance_cycling"
    case distanceDownhillSnowSports = "distance_downhill_snow_sports"
    case distancePaddleSports = "distance_paddle_sports"
    case distanceRowing = "distance_rowing"
    case distanceSkatingSports = "distance_skating_sports"
    case distanceSwimming = "distance_swimming"
    case distanceWalkingRunning = "distance_walking_running"
    case distanceWheelchair = "distance_wheelchair"
    case estimatedWorkoutEffortScore = "estimated_workout_effort_score"
    case flightsClimbed = "flights_climbed"
    case nikeFuel = "nike_fuel"
    case paddleSportsSpeed = "paddle_sports_speed"
    case physicalEffort = "physical_effort"
    case pushCount = "push_count"
    case rowingSpeed = "rowing_speed"
    case runningPower = "running_power"
    case runningSpeed = "running_speed"
    case stepCount = "step_count"
    case swimmingStrokeCount = "swimming_stroke_count"
    case underwaterDepth = "underwater_depth"
    case workoutEffortScore = "workout_effort_score"
    case environmentalAudioExposure = "environmental_audio_exposure"
    case environmentalSoundReduction = "environmental_sound_reduction"
    case headphoneAudioExposure = "headphone_audio_exposure"
    case atrialFibrillationBurden = "atrial_fibrillation_burden"
    case heartRate = "heart_rate"
    case heartRateRecoveryOneMinute = "heart_rate_recovery_one_minute"
    case restingHeartRate = "resting_heart_rate"
    case hrvSDNN = "hrv_sdnn"
    case peripheralPerfusionIndex = "peripheral_perfusion_index"
    case vo2Max = "vo2_max"
    case walkingHeartRateAverage = "walking_heart_rate_average"
    case appleWalkingSteadiness = "apple_walking_steadiness"
    case runningGroundContactTime = "running_ground_contact_time"
    case runningStrideLength = "running_stride_length"
    case runningVerticalOscillation = "running_vertical_oscillation"
    case sixMinuteWalkTestDistance = "six_minute_walk_test_distance"
    case stairAscentSpeed = "stair_ascent_speed"
    case stairDescentSpeed = "stair_descent_speed"
    case walkingAsymmetryPercentage = "walking_asymmetry_percentage"
    case walkingDoubleSupportPercentage = "walking_double_support_percentage"
    case walkingSpeed = "walking_speed"
    case walkingStepLength = "walking_step_length"
    case dietaryBiotin = "dietary_biotin"
    case dietaryCaffeine = "dietary_caffeine"
    case dietaryCalcium = "dietary_calcium"
    case dietaryEnergy = "dietary_energy"
    case dietaryCarbohydrates = "dietary_carbs"
    case dietaryChloride = "dietary_chloride"
    case dietaryCholesterol = "dietary_cholesterol"
    case dietaryChromium = "dietary_chromium"
    case dietaryCopper = "dietary_copper"
    case dietaryFatMonounsaturated = "dietary_fat_monounsaturated"
    case dietaryFatPolyunsaturated = "dietary_fat_polyunsaturated"
    case dietaryFatSaturated = "dietary_fat_saturated"
    case dietaryFat = "dietary_fat"
    case dietaryFiber = "dietary_fiber"
    case dietaryFolate = "dietary_folate"
    case dietaryIodine = "dietary_iodine"
    case dietaryIron = "dietary_iron"
    case dietaryMagnesium = "dietary_magnesium"
    case dietaryManganese = "dietary_manganese"
    case dietaryMolybdenum = "dietary_molybdenum"
    case dietaryNiacin = "dietary_niacin"
    case dietaryPantothenicAcid = "dietary_pantothenic_acid"
    case dietaryPhosphorus = "dietary_phosphorus"
    case dietaryPotassium = "dietary_potassium"
    case dietaryProtein = "dietary_protein"
    case dietaryRiboflavin = "dietary_riboflavin"
    case dietarySelenium = "dietary_selenium"
    case dietarySodium = "dietary_sodium"
    case dietarySugar = "dietary_sugar"
    case dietaryThiamin = "dietary_thiamin"
    case dietaryVitaminA = "dietary_vitamin_a"
    case dietaryVitaminB12 = "dietary_vitamin_b12"
    case dietaryVitaminB6 = "dietary_vitamin_b6"
    case dietaryVitaminC = "dietary_vitamin_c"
    case dietaryVitaminD = "dietary_vitamin_d"
    case dietaryVitaminE = "dietary_vitamin_e"
    case dietaryVitaminK = "dietary_vitamin_k"
    case water = "water"
    case dietaryZinc = "dietary_zinc"
    case bloodAlcoholContent = "blood_alcohol_content"
    case bloodPressureDiastolic = "blood_pressure_diastolic"
    case bloodPressureSystolic = "blood_pressure_systolic"
    case insulinDelivery = "insulin_delivery"
    case numberOfAlcoholicBeverages = "number_of_alcoholic_beverages"
    case numberOfTimesFallen = "number_of_times_fallen"
    case timeInDaylight = "time_in_daylight"
    case uvExposure = "uv_exposure"
    case waterTemperature = "water_temperature"
    case basalBodyTemperature = "basal_body_temperature"
    case appleSleepingBreathingDisturbances = "apple_sleeping_breathing_disturbances"
    case forcedExpiratoryVolume1 = "forced_expiratory_volume_1"
    case forcedVitalCapacity = "forced_vital_capacity"
    case inhalerUsage = "inhaler_usage"
    case oxygenSaturation = "oxygen_saturation"
    case peakExpiratoryFlowRate = "peak_expiratory_flow_rate"
    case respiratoryRate = "respiratory_rate"
    case bloodGlucose = "blood_glucose"
    case bodyTemperature = "body_temperature"
    case appleStandHour = "apple_stand_hour"
    case environmentalAudioExposureEvent = "environmental_audio_exposure_event"
    case headphoneAudioExposureEvent = "headphone_audio_exposure_event"
    case highHeartRateEvent = "high_heart_rate_event"
    case irregularHeartRhythmEvent = "irregular_heart_rhythm_event"
    case lowCardioFitnessEvent = "low_cardio_fitness_event"
    case lowHeartRateEvent = "low_heart_rate_event"
    case mindfulSession = "mindful_session"
    case appleWalkingSteadinessEvent = "apple_walking_steadiness_event"
    case handwashingEvent = "handwashing_event"
    case toothbrushingEvent = "toothbrushing_event"
    case bleedingAfterPregnancy = "bleeding_after_pregnancy"
    case bleedingDuringPregnancy = "bleeding_during_pregnancy"
    case cervicalMucusQuality = "cervical_mucus_quality"
    case contraceptive = "contraceptive"
    case infrequentMenstrualCycles = "infrequent_menstrual_cycles"
    case intermenstrualBleeding = "intermenstrual_bleeding"
    case irregularMenstrualCycles = "irregular_menstrual_cycles"
    case lactation = "lactation"
    case menstrualFlow = "menstrual_flow"
    case ovulationTestResult = "ovulation_test_result"
    case persistentIntermenstrualBleeding = "persistent_intermenstrual_bleeding"
    case pregnancy = "pregnancy"
    case pregnancyTestResult = "pregnancy_test_result"
    case progesteroneTestResult = "progesterone_test_result"
    case prolongedMenstrualPeriods = "prolonged_menstrual_periods"
    case sexualActivity = "sexual_activity"
    case sleepApneaEvent = "sleep_apnea_event"
    case sleepAnalysis = "sleep_analysis"
    case abdominalCramps = "abdominal_cramps"
    case acne = "acne"
    case appetiteChanges = "appetite_changes"
    case bladderIncontinence = "bladder_incontinence"
    case bloating = "bloating"
    case breastPain = "breast_pain"
    case chestTightnessOrPain = "chest_tightness_or_pain"
    case chills = "chills"
    case constipation = "constipation"
    case coughing = "coughing"
    case diarrhea = "diarrhea"
    case dizziness = "dizziness"
    case drySkin = "dry_skin"
    case fainting = "fainting"
    case fatigue = "fatigue"
    case fever = "fever"
    case generalizedBodyAche = "generalized_body_ache"
    case hairLoss = "hair_loss"
    case headache = "headache"
    case heartburn = "heartburn"
    case hotFlashes = "hot_flashes"
    case lossOfSmell = "loss_of_smell"
    case lossOfTaste = "loss_of_taste"
    case lowerBackPain = "lower_back_pain"
    case memoryLapse = "memory_lapse"
    case moodChanges = "mood_changes"
    case nausea = "nausea"
    case nightSweats = "night_sweats"
    case pelvicPain = "pelvic_pain"
    case rapidPoundingOrFlutteringHeartbeat = "rapid_pounding_or_fluttering_heartbeat"
    case runnyNose = "runny_nose"
    case shortnessOfBreath = "shortness_of_breath"
    case sinusCongestion = "sinus_congestion"
    case skippedHeartbeat = "skipped_heartbeat"
    case sleepChanges = "sleep_changes"
    case soreThroat = "sore_throat"
    case vaginalDryness = "vaginal_dryness"
    case vomiting = "vomiting"
    case wheezing = "wheezing"
    case workouts = "workouts"

    var id: String { rawValue }

    static let dietaryTypes: Set<HealthDataType> = [
        .dietaryBiotin,
        .dietaryCaffeine,
        .dietaryCalcium,
        .dietaryEnergy,
        .dietaryCarbohydrates,
        .dietaryChloride,
        .dietaryCholesterol,
        .dietaryChromium,
        .dietaryCopper,
        .dietaryFatMonounsaturated,
        .dietaryFatPolyunsaturated,
        .dietaryFatSaturated,
        .dietaryFat,
        .dietaryFiber,
        .dietaryFolate,
        .dietaryIodine,
        .dietaryIron,
        .dietaryMagnesium,
        .dietaryManganese,
        .dietaryMolybdenum,
        .dietaryNiacin,
        .dietaryPantothenicAcid,
        .dietaryPhosphorus,
        .dietaryPotassium,
        .dietaryProtein,
        .dietaryRiboflavin,
        .dietarySelenium,
        .dietarySodium,
        .dietarySugar,
        .dietaryThiamin,
        .dietaryVitaminA,
        .dietaryVitaminB12,
        .dietaryVitaminB6,
        .dietaryVitaminC,
        .dietaryVitaminD,
        .dietaryVitaminE,
        .dietaryVitaminK,
        .water,
        .dietaryZinc
    ]

    var label: String {
        switch self {
        case .vo2Max: "VO2 max"
        case .hrvSDNN: "HRV"
        case .uvExposure: "UV exposure"
        case .forcedExpiratoryVolume1: "Forced expiratory volume 1"
        case .dietaryCarbohydrates: "Dietary carbohydrates"
        case .dietaryFat: "Dietary fat"
        case .water: "Water"
        case .stepCount: "Steps"
        case .heartRate: "Heart rate"
        case .restingHeartRate: "Resting heart rate"
        case .activeEnergy: "Active energy"
        case .basalEnergy: "Basal energy"
        case .bodyMass: "Weight/body mass"
        case .bodyFatPercentage: "Body fat percentage"
        case .dietaryEnergy: "Dietary energy"
        case .dietaryProtein: "Dietary protein"
        case .sleepAnalysis: "Sleep"
        case .workouts: "Workouts"
        default:
            rawValue
                .split(separator: "_")
                .map { word in word.prefix(1).uppercased() + word.dropFirst() }
                .joined(separator: " ")
        }
    }

    var kind: HealthDataKind {
        switch self {
        case .workouts:
            .workout
        case .appleStandHour, .environmentalAudioExposureEvent, .headphoneAudioExposureEvent, .highHeartRateEvent,
             .irregularHeartRhythmEvent, .lowCardioFitnessEvent, .lowHeartRateEvent, .mindfulSession,
             .appleWalkingSteadinessEvent, .handwashingEvent, .toothbrushingEvent, .bleedingAfterPregnancy,
             .bleedingDuringPregnancy, .cervicalMucusQuality, .contraceptive, .infrequentMenstrualCycles,
             .intermenstrualBleeding, .irregularMenstrualCycles, .lactation, .menstrualFlow, .ovulationTestResult,
             .persistentIntermenstrualBleeding, .pregnancy, .pregnancyTestResult, .progesteroneTestResult,
             .prolongedMenstrualPeriods, .sexualActivity, .sleepApneaEvent, .sleepAnalysis, .abdominalCramps,
             .acne, .appetiteChanges, .bladderIncontinence, .bloating, .breastPain, .chestTightnessOrPain,
             .chills, .constipation, .coughing, .diarrhea, .dizziness, .drySkin, .fainting, .fatigue, .fever,
             .generalizedBodyAche, .hairLoss, .headache, .heartburn, .hotFlashes, .lossOfSmell, .lossOfTaste,
             .lowerBackPain, .memoryLapse, .moodChanges, .nausea, .nightSweats, .pelvicPain,
             .rapidPoundingOrFlutteringHeartbeat, .runnyNose, .shortnessOfBreath, .sinusCongestion,
             .skippedHeartbeat, .sleepChanges, .soreThroat, .vaginalDryness, .vomiting, .wheezing:
            .category
        default:
            .quantity
        }
    }

    var healthKitIdentifierRawValue: String? {
        switch kind {
        case .quantity:
            "HKQuantityTypeIdentifier\(healthKitIdentifierSuffix)"
        case .category:
            "HKCategoryTypeIdentifier\(healthKitIdentifierSuffix)"
        case .workout:
            nil
        }
    }

    var preferredSampleUnit: HealthSampleUnit? {
        guard kind == .quantity else { return nil }

        switch self {
        case .heartRate, .heartRateRecoveryOneMinute, .restingHeartRate, .walkingHeartRateAverage,
             .cyclingCadence, .respiratoryRate:
            return .countPerMinute
        case .hrvSDNN, .runningGroundContactTime:
            return .millisecond
        case .appleExerciseTime, .appleMoveTime, .appleStandTime, .timeInDaylight:
            return .minute
        case .activeEnergy, .basalEnergy, .dietaryEnergy:
            return .kilocalorie
        case .bodyMass, .leanBodyMass:
            return .kilogram
        case .dietaryBiotin, .dietaryCaffeine, .dietaryCalcium, .dietaryCarbohydrates, .dietaryChloride,
             .dietaryCholesterol, .dietaryChromium, .dietaryCopper, .dietaryFatMonounsaturated,
             .dietaryFatPolyunsaturated, .dietaryFatSaturated, .dietaryFat, .dietaryFiber, .dietaryFolate,
             .dietaryIodine, .dietaryIron, .dietaryMagnesium, .dietaryManganese, .dietaryMolybdenum,
             .dietaryNiacin, .dietaryPantothenicAcid, .dietaryPhosphorus, .dietaryPotassium, .dietaryProtein,
             .dietaryRiboflavin, .dietarySelenium, .dietarySodium, .dietarySugar, .dietaryThiamin,
             .dietaryVitaminA, .dietaryVitaminB12, .dietaryVitaminB6, .dietaryVitaminC, .dietaryVitaminD,
             .dietaryVitaminE, .dietaryVitaminK, .dietaryZinc:
            return .gram
        case .bodyFatPercentage, .atrialFibrillationBurden, .peripheralPerfusionIndex, .appleWalkingSteadiness,
             .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage, .bloodAlcoholContent, .oxygenSaturation:
            return .percent
        case .water:
            return .milliliter
        case .height, .waistCircumference, .distanceCrossCountrySkiing, .distanceCycling,
             .distanceDownhillSnowSports, .distancePaddleSports, .distanceRowing, .distanceSkatingSports,
             .distanceSwimming, .distanceWalkingRunning, .distanceWheelchair, .underwaterDepth,
             .runningStrideLength, .sixMinuteWalkTestDistance, .walkingStepLength:
            return .meter
        case .runningVerticalOscillation:
            return .centimeter
        case .crossCountrySkiingSpeed, .cyclingSpeed, .paddleSportsSpeed, .rowingSpeed, .runningSpeed,
             .stairAscentSpeed, .stairDescentSpeed, .walkingSpeed:
            return .meterPerSecond
        case .cyclingFunctionalThresholdPower, .cyclingPower, .runningPower:
            return .watt
        case .appleSleepingWristTemperature, .waterTemperature, .basalBodyTemperature, .bodyTemperature:
            return .degreeCelsius
        case .electrodermalActivity:
            return .siemens
        case .environmentalAudioExposure, .environmentalSoundReduction, .headphoneAudioExposure:
            return .decibelASPL
        case .bloodPressureDiastolic, .bloodPressureSystolic:
            return .millimeterOfMercury
        case .insulinDelivery:
            return .internationalUnit
        case .vo2Max:
            return .milliliterPerKilogramMinute
        case .forcedExpiratoryVolume1, .forcedVitalCapacity:
            return .liter
        case .peakExpiratoryFlowRate:
            return .literPerMinute
        case .bloodGlucose:
            return .milligramPerDeciliter
        case .physicalEffort:
            return .kilocaloriePerKilogramHour
        case .estimatedWorkoutEffortScore, .workoutEffortScore:
            return .appleEffortScore
        case .stepCount, .bodyMassIndex, .flightsClimbed, .nikeFuel, .pushCount, .swimmingStrokeCount,
             .appleSleepingBreathingDisturbances, .inhalerUsage, .numberOfAlcoholicBeverages,
             .numberOfTimesFallen, .uvExposure:
            return .count
        default:
            return nil
        }
    }

    private var healthKitIdentifierSuffix: String {
        switch self {
        case .activeEnergy: return "ActiveEnergyBurned"
        case .basalEnergy: return "BasalEnergyBurned"
        case .dietaryEnergy: return "DietaryEnergyConsumed"
        case .dietaryFat: return "DietaryFatTotal"
        case .water: return "DietaryWater"
        case .hrvSDNN: return "HeartRateVariabilitySDNN"
        case .vo2Max: return "VO2Max"
        case .uvExposure: return "UVExposure"
        default:
            let name = String(describing: self)
            return name.prefix(1).uppercased() + name.dropFirst()
        }
    }
}

enum HealthMetricCategory: String, CaseIterable, Identifiable, Equatable {
    case bodyMeasurements
    case activity
    case heart
    case mobility
    case nutrition
    case hearingEnvironment
    case clinical
    case respiratory
    case sleepMindfulness
    case reproductiveHealth
    case symptomsEvents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyMeasurements:
            "Body"
        case .activity:
            "Activity"
        case .heart:
            "Heart"
        case .mobility:
            "Mobility"
        case .nutrition:
            "Nutrition"
        case .hearingEnvironment:
            "Hearing & Environment"
        case .clinical:
            "Clinical"
        case .respiratory:
            "Respiratory"
        case .sleepMindfulness:
            "Sleep & Mindfulness"
        case .reproductiveHealth:
            "Reproductive Health"
        case .symptomsEvents:
            "Symptoms & Events"
        }
    }

    var subtitle: String {
        switch self {
        case .bodyMeasurements:
            "Body composition, temperature, and measurements."
        case .activity:
            "Movement, energy, distance, and workout metrics."
        case .heart:
            "Heart rate, rhythm, cardio, and blood pressure."
        case .mobility:
            "Walking steadiness, gait, stairs, and fall-related metrics."
        case .nutrition:
            "Dietary intake, hydration, vitamins, and minerals."
        case .hearingEnvironment:
            "Audio exposure, daylight, UV, and environmental readings."
        case .clinical:
            "Glucose, insulin, alcohol, and related clinical values."
        case .respiratory:
            "Breathing, oxygen, lung capacity, and respiratory symptoms."
        case .sleepMindfulness:
            "Sleep, mindfulness, and rest-related records."
        case .reproductiveHealth:
            "Cycle tracking, pregnancy, and reproductive records."
        case .symptomsEvents:
            "Symptoms, hygiene events, and other Apple Health records."
        }
    }

    var types: [HealthDataType] {
        HealthDataType.allCases.filter { Self.category(for: $0) == self }
    }

    static func category(for type: HealthDataType) -> HealthMetricCategory {
        if type.rawValue.hasPrefix("dietary_") || type == .water {
            return .nutrition
        }

        switch type {
        case .appleSleepingWristTemperature, .bodyFatPercentage, .bodyMass, .bodyMassIndex,
             .electrodermalActivity, .height, .leanBodyMass, .waistCircumference,
             .basalBodyTemperature, .bodyTemperature:
            return .bodyMeasurements
        case .activeEnergy, .appleExerciseTime, .appleMoveTime, .appleStandTime, .basalEnergy,
             .crossCountrySkiingSpeed, .cyclingCadence, .cyclingFunctionalThresholdPower, .cyclingPower,
             .cyclingSpeed, .distanceCrossCountrySkiing, .distanceCycling, .distanceDownhillSnowSports,
             .distancePaddleSports, .distanceRowing, .distanceSkatingSports, .distanceSwimming,
             .distanceWalkingRunning, .distanceWheelchair, .estimatedWorkoutEffortScore, .flightsClimbed,
             .nikeFuel, .paddleSportsSpeed, .physicalEffort, .pushCount, .rowingSpeed, .runningPower,
             .runningSpeed, .stepCount, .swimmingStrokeCount, .underwaterDepth, .workoutEffortScore,
             .workouts:
            return .activity
        case .atrialFibrillationBurden, .heartRate, .heartRateRecoveryOneMinute, .restingHeartRate,
             .hrvSDNN, .peripheralPerfusionIndex, .vo2Max, .walkingHeartRateAverage,
             .bloodPressureDiastolic, .bloodPressureSystolic, .highHeartRateEvent,
             .irregularHeartRhythmEvent, .lowCardioFitnessEvent, .lowHeartRateEvent,
             .rapidPoundingOrFlutteringHeartbeat, .skippedHeartbeat:
            return .heart
        case .appleWalkingSteadiness, .runningGroundContactTime, .runningStrideLength,
             .runningVerticalOscillation, .sixMinuteWalkTestDistance, .stairAscentSpeed,
             .stairDescentSpeed, .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage,
             .walkingSpeed, .walkingStepLength, .appleWalkingSteadinessEvent, .numberOfTimesFallen:
            return .mobility
        case .environmentalAudioExposure, .environmentalSoundReduction, .headphoneAudioExposure,
             .environmentalAudioExposureEvent, .headphoneAudioExposureEvent, .timeInDaylight,
             .uvExposure, .waterTemperature:
            return .hearingEnvironment
        case .bloodAlcoholContent, .bloodGlucose, .insulinDelivery, .numberOfAlcoholicBeverages:
            return .clinical
        case .appleSleepingBreathingDisturbances, .forcedExpiratoryVolume1, .forcedVitalCapacity,
             .inhalerUsage, .oxygenSaturation, .peakExpiratoryFlowRate, .respiratoryRate,
             .sleepApneaEvent, .chestTightnessOrPain, .coughing, .shortnessOfBreath, .wheezing:
            return .respiratory
        case .mindfulSession, .nightSweats, .sleepAnalysis, .sleepChanges:
            return .sleepMindfulness
        case .bleedingAfterPregnancy, .bleedingDuringPregnancy, .cervicalMucusQuality, .contraceptive,
             .infrequentMenstrualCycles, .intermenstrualBleeding, .irregularMenstrualCycles, .lactation,
             .menstrualFlow, .ovulationTestResult, .persistentIntermenstrualBleeding, .pregnancy,
             .pregnancyTestResult, .progesteroneTestResult, .prolongedMenstrualPeriods, .sexualActivity,
             .vaginalDryness:
            return .reproductiveHealth
        default:
            return .symptomsEvents
        }
    }
}

enum HealthSampleUnit: String, Codable, Equatable {
    case count
    case countPerMinute
    case countPerSecond
    case millisecond
    case second
    case minute
    case kilocalorie
    case kilojoule
    case joule
    case kilogram
    case gram
    case percent
    case fraction
    case milliliter
    case liter
    case meter
    case centimeter
    case meterPerSecond
    case watt
    case degreeCelsius
    case siemens
    case decibelASPL
    case millimeterOfMercury
    case internationalUnit
    case milliliterPerKilogramMinute
    case literPerMinute
    case milligramPerDeciliter
    case kilocaloriePerKilogramHour
    case appleEffortScore

    var backendUnit: String {
        switch self {
        case .count: "count"
        case .countPerMinute: "count/min"
        case .countPerSecond: "count/s"
        case .millisecond: "ms"
        case .second: "seconds"
        case .minute: "minutes"
        case .kilocalorie: "kcal"
        case .kilojoule: "kJ"
        case .joule: "J"
        case .kilogram: "kg"
        case .gram: "g"
        case .percent: "percent"
        case .fraction: "fraction"
        case .milliliter: "mL"
        case .liter: "L"
        case .meter: "m"
        case .centimeter: "cm"
        case .meterPerSecond: "m/s"
        case .watt: "W"
        case .degreeCelsius: "degC"
        case .siemens: "S"
        case .decibelASPL: "dBASPL"
        case .millimeterOfMercury: "mmHg"
        case .internationalUnit: "IU"
        case .milliliterPerKilogramMinute: "mL/kg/min"
        case .literPerMinute: "L/min"
        case .milligramPerDeciliter: "mg/dL"
        case .kilocaloriePerKilogramHour: "kcal/kg/hr"
        case .appleEffortScore: "appleEffortScore"
        }
    }

    var healthKitUnitString: String {
        switch self {
        case .count: "count"
        case .countPerMinute: "count/min"
        case .countPerSecond: "count/s"
        case .millisecond: "ms"
        case .second: "s"
        case .minute: "min"
        case .kilocalorie: "kcal"
        case .kilojoule: "kJ"
        case .joule: "J"
        case .kilogram: "kg"
        case .gram: "g"
        case .percent: "%"
        case .fraction: "%"
        case .milliliter: "mL"
        case .liter: "L"
        case .meter: "m"
        case .centimeter: "cm"
        case .meterPerSecond: "m/s"
        case .watt: "W"
        case .degreeCelsius: "degC"
        case .siemens: "S"
        case .decibelASPL: "dBASPL"
        case .millimeterOfMercury: "mmHg"
        case .internationalUnit: "IU"
        case .milliliterPerKilogramMinute: "mL/(kg*min)"
        case .literPerMinute: "L/min"
        case .milligramPerDeciliter: "mg/dL"
        case .kilocaloriePerKilogramHour: "kcal/(kg*hr)"
        case .appleEffortScore: "appleEffortScore"
        }
    }
}

enum HealthDataKind {
    case quantity
    case category
    case workout
}

struct HealthQuantitySampleDTO: Equatable {
    let uuid: UUID
    let type: HealthDataType
    let value: Double
    let unit: HealthSampleUnit
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleIdentifier: String?
    let metadata: [String: String]
    let stableIDOverride: String?

    init(
        uuid: UUID,
        type: HealthDataType,
        value: Double,
        unit: HealthSampleUnit,
        startAt: Date,
        endAt: Date,
        sourceName: String,
        sourceBundleIdentifier: String?,
        metadata: [String: String],
        stableIDOverride: String? = nil
    ) {
        self.uuid = uuid
        self.type = type
        self.value = value
        self.unit = unit
        self.startAt = startAt
        self.endAt = endAt
        self.sourceName = sourceName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.metadata = metadata
        self.stableIDOverride = stableIDOverride
    }
}

struct HealthSleepSampleDTO: Equatable {
    let uuid: UUID
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleIdentifier: String?
    let stage: String
    let metadata: [String: String]
}

struct HealthCategorySampleDTO: Equatable {
    let uuid: UUID
    let type: HealthDataType
    let value: Int
    let valueLabel: String
    let startAt: Date
    let endAt: Date
    let sourceName: String
    let sourceBundleIdentifier: String?
    let metadata: [String: String]
}

struct HealthWorkoutSampleDTO: Equatable {
    let uuid: UUID
    let activityType: String
    let startAt: Date
    let endAt: Date
    let durationSeconds: Double
    let totalEnergyKcal: Double?
    let activeEnergyKcal: Double?
    let distanceMeters: Double?
    let sourceName: String
    let sourceBundleIdentifier: String?
    let metadata: [String: String]
}

enum NormalizationError: LocalizedError, Equatable {
    case unsupportedUnit(type: HealthDataType, unit: HealthSampleUnit)

    var errorDescription: String? {
        switch self {
        case let .unsupportedUnit(type, unit):
            "Cannot convert \(type.label) from \(unit.rawValue)"
        }
    }
}

struct HealthNormalizer {
    func metrics(from samples: [HealthQuantitySampleDTO]) throws -> [HealthMetric] {
        try samples.map { sample in
            let converted = try convert(value: sample.value, unit: sample.unit, type: sample.type)
            return HealthMetric(
                id: sample.stableIDOverride ?? stableID(for: sample.uuid),
                type: sample.type.rawValue,
                value: converted.value,
                unit: converted.unit,
                startAt: sample.startAt,
                endAt: sample.endAt,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: sample.metadata
            )
        }
    }

    func sleepMetrics(from samples: [HealthSleepSampleDTO]) -> [HealthMetric] {
        samples.map { sample in
            var metadata = sample.metadata
            metadata["sleep_stage"] = sample.stage
            return HealthMetric(
                id: stableID(for: sample.uuid),
                type: HealthDataType.sleepAnalysis.rawValue,
                value: sample.endAt.timeIntervalSince(sample.startAt),
                unit: "seconds",
                startAt: sample.startAt,
                endAt: sample.endAt,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: metadata
            )
        }
    }

    func categoryMetrics(from samples: [HealthCategorySampleDTO]) -> [HealthMetric] {
        samples.map { sample in
            var metadata = sample.metadata
            metadata["category_value"] = String(sample.value)
            metadata["category_label"] = sample.valueLabel

            if sample.type == .sleepAnalysis {
                metadata["sleep_stage"] = sample.valueLabel
                return HealthMetric(
                    id: stableID(for: sample.uuid),
                    type: sample.type.rawValue,
                    value: sample.endAt.timeIntervalSince(sample.startAt),
                    unit: HealthSampleUnit.second.backendUnit,
                    startAt: sample.startAt,
                    endAt: sample.endAt,
                    sourceName: sample.sourceName,
                    sourceBundleID: sample.sourceBundleIdentifier,
                    metadata: metadata
                )
            }

            return HealthMetric(
                id: stableID(for: sample.uuid),
                type: sample.type.rawValue,
                value: Double(sample.value),
                unit: "category_value",
                startAt: sample.startAt,
                endAt: sample.endAt,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: metadata
            )
        }
    }

    func workouts(from samples: [HealthWorkoutSampleDTO]) -> [HealthWorkout] {
        samples.map { sample in
            HealthWorkout(
                id: stableID(for: sample.uuid),
                activityType: sample.activityType,
                startAt: sample.startAt,
                endAt: sample.endAt,
                durationSeconds: sample.durationSeconds,
                totalEnergyKcal: sample.totalEnergyKcal,
                activeEnergyKcal: sample.activeEnergyKcal,
                distanceMeters: sample.distanceMeters,
                sourceName: sample.sourceName,
                sourceBundleID: sample.sourceBundleIdentifier,
                metadata: sample.metadata
            )
        }
    }

    func payload(
        deviceID: String,
        dateRange: SyncDateRange,
        timezone: String = TimeZone.current.identifier,
        quantitySamples: [HealthQuantitySampleDTO],
        sleepSamples: [HealthSleepSampleDTO],
        categorySamples: [HealthCategorySampleDTO] = [],
        workoutSamples: [HealthWorkoutSampleDTO],
        deletions: [HealthRecordDeletion] = [],
        generatedAt: Date = Date()
    ) throws -> SyncPayload {
        SyncPayload(
            deviceID: deviceID,
            exportID: UUID(),
            generatedAt: generatedAt,
            timezone: timezone,
            source: "ios-healthkit",
            schemaVersion: 2,
            dateRange: dateRange,
            metrics: try metrics(from: quantitySamples) + sleepMetrics(from: sleepSamples) + categoryMetrics(from: categorySamples),
            workouts: workouts(from: workoutSamples),
            deletions: deletions
        )
    }

    private func stableID(for uuid: UUID) -> String {
        "healthkit:\(uuid.uuidString)"
    }

    private func convert(value: Double, unit: HealthSampleUnit, type: HealthDataType) throws -> (value: Double, unit: String) {
        if let preferredUnit = type.preferredSampleUnit, unit == preferredUnit {
            return (value, unit.backendUnit)
        }

        switch type {
        case .stepCount:
            guard unit == .count else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, unit.backendUnit)
        case .heartRate, .restingHeartRate:
            switch unit {
            case .countPerMinute: return (value, HealthSampleUnit.countPerMinute.backendUnit)
            case .countPerSecond: return (value * 60, HealthSampleUnit.countPerMinute.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .respiratoryRate:
            switch unit {
            case .countPerMinute: return (value, HealthSampleUnit.countPerMinute.backendUnit)
            case .countPerSecond: return (value * 60, HealthSampleUnit.countPerMinute.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .hrvSDNN:
            switch unit {
            case .millisecond: return (value, HealthSampleUnit.millisecond.backendUnit)
            case .second: return (value * 1_000, HealthSampleUnit.millisecond.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .activeEnergy, .basalEnergy, .dietaryEnergy:
            switch unit {
            case .kilocalorie: return (value, HealthSampleUnit.kilocalorie.backendUnit)
            case .kilojoule: return (value / 4.184, HealthSampleUnit.kilocalorie.backendUnit)
            case .joule: return (value / 4_184, HealthSampleUnit.kilocalorie.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .bodyMass:
            guard unit == .kilogram else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, HealthSampleUnit.kilogram.backendUnit)
        case .bodyFatPercentage:
            switch unit {
            case .percent: return (value, HealthSampleUnit.percent.backendUnit)
            case .fraction: return (value * 100, HealthSampleUnit.percent.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat:
            guard unit == .gram else { throw NormalizationError.unsupportedUnit(type: type, unit: unit) }
            return (value, HealthSampleUnit.gram.backendUnit)
        case .water:
            switch unit {
            case .milliliter: return (value, HealthSampleUnit.milliliter.backendUnit)
            case .liter: return (value * 1_000, HealthSampleUnit.milliliter.backendUnit)
            default: throw NormalizationError.unsupportedUnit(type: type, unit: unit)
            }
        case _ where type.kind != .quantity:
            throw NormalizationError.unsupportedUnit(type: type, unit: unit)
        default:
            throw NormalizationError.unsupportedUnit(type: type, unit: unit)
        }
    }
}
