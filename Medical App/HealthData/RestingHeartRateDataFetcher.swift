import HealthKit

class RestingHeartRateDataFetcher {
    static let healthStore = HKHealthStore()
    
    /// Fetches the daily average resting heart rate for the last number of days
    static func fetchDailyAverageRestingHeartRate(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Int)]) -> Void) {
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(quantityType: restingHRType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: startDate, intervalComponents: DateComponents(day: 1))

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                completion([])
                return
            }

            var data: [(Date, Int)] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let restingHR = statistics.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) ?? 0.0
                data.append((statistics.startDate, Int(restingHR)))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }

    /// Fetches resting heart rate data with exact timestamps for the last number of days
    static func fetchRestingHeartRateWithTimestamps(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: restingHRType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }

            var data: [(Date, Double)] = []
            for sample in samples {
                let restingHR = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                data.append((sample.startDate, restingHR))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }
}
