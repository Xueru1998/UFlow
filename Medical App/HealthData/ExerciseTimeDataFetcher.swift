import HealthKit

class ExerciseTimeDataFetcher {
    static let healthStore = HKHealthStore()

    static func fetchLatestExerciseMinutes(completion: @escaping (String) -> Void) {
        let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion("")
                return
            }
            let minutes = Int(sum.doubleValue(for: HKUnit.minute()))
            completion("\(minutes)")
        }

        healthStore.execute(query)
    }
}
