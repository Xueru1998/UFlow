import HealthKit

class HRVDataFetcher {
    static func fetchDailyAverageHRV(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Int)]) -> Void) {
        let healthStore = HKHealthStore()
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: startDate, intervalComponents: DateComponents(day: 1))

        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                completion([])
                return
            }

            var data: [(Date, Int)] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let hrv = statistics.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli)) ?? 0.0
                data.append((statistics.startDate, Int(hrv)))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }
    
    static func fetchHRVWithTimestamps(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        let healthStore = HKHealthStore()
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }

            var data: [(Date, Double)] = []
            for sample in samples {
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                data.append((sample.startDate, hrv))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }
}
