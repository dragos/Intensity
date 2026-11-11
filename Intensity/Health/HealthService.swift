import Foundation
import HealthKit

/// Saves finished workouts to Apple Health and reads back heart rate.
@MainActor
final class HealthService {
    static let shared = HealthService()

    struct SavedWorkout {
        var activeEnergy: Double?
        var averageHeartRate: Double?
        var maxHeartRate: Double?
    }

    private let store = HKHealthStore()
    private let shareTypes: Set<HKSampleType> = [.workoutType(), HKQuantityType(.activeEnergyBurned)]
    private let readTypes: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.bodyMass)]

    /// False on devices without Health, such as some iPads.
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether the user allowed saving workouts. (iOS never reveals whether read access
    /// was granted; queries just come back empty.)
    var canSaveWorkouts: Bool {
        isAvailable && store.authorizationStatus(for: .workoutType()) == .sharingAuthorized
    }

    /// Shows the system Health permission sheet, the first time only.
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Saves the workout as High Intensity Interval Training, with each work interval as a
    /// segment, pauses, and estimated active energy when the user's weight is known.
    func save(_ recording: WorkoutRecording, workoutName: String) async throws -> SavedWorkout {
        guard let start = recording.start, let end = recording.end else { return SavedWorkout() }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .highIntensityIntervalTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        var events = recording.intervals
            .filter { $0.kind == .work }
            .map { HKWorkoutEvent(type: .segment, dateInterval: $0.dates, metadata: nil) }
        for pause in recording.pausesDuringWorkout {
            events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil))
            events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil))
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events.sorted { $0.dateInterval.start < $1.dateInterval.start })
        }

        var saved = SavedWorkout()
        if let bodyMass = await latestBodyMassKg() {
            let kilocalories = recording.estimatedCalories(bodyMassKg: bodyMass)
            let sample = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kilocalories),
                                          start: start, end: end)
            try await builder.addSamples([sample])
            saved.activeEnergy = kilocalories
        }

        try await builder.addMetadata([HKMetadataKeyIndoorWorkout: true, "IntensityWorkoutName": workoutName])
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()

        if let heartRate = await heartRate(from: start, to: end) {
            saved.averageHeartRate = heartRate.average
            saved.maxHeartRate = heartRate.max
        }
        return saved
    }

    /// The most recent body weight in Health, if the user allowed reading it.
    private func latestBodyMassKg() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        let sample = try? await descriptor.result(for: store).first
        return sample?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Average and peak heart rate during the workout. Only available when something like an
    /// Apple Watch recorded heart rate at the time.
    private func heartRate(from start: Date, to end: Date) async -> (average: Double, max: Double)? {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.heartRate),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: [.discreteAverage, .discreteMax])
        let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
        guard let statistics = try? await descriptor.result(for: store),
              let average = statistics.averageQuantity()?.doubleValue(for: beatsPerMinute),
              let max = statistics.maximumQuantity()?.doubleValue(for: beatsPerMinute)
        else { return nil }
        return (average, max)
    }
}
