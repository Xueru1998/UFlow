import HealthKit

class StepsDataFetcher {
    static let healthStore = HKHealthStore()

    static func fetchLatestSteps(completion: @escaping (String) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion("")
                return
            }
            let stepCount = Int(sum.doubleValue(for: HKUnit.count()))
            completion("\(stepCount)")
        }

        healthStore.execute(query)
    }

    static func fetchSteps(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Int)]) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: DateComponents(day: 1))

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                completion([])
                return
            }

            var data: [(Date, Int)] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0
                data.append((statistics.startDate, Int(steps)))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }
}
