import HealthKit

class WristTemperatureDataFetcher {
    static func fetchWristTemperatureWithTimestamps(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        let healthStore = HKHealthStore()
        let wristTemperatureType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: wristTemperatureType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }

            var data: [(Date, Double)] = []
            for sample in samples {
                let temp = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                data.append((sample.startDate, temp))
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }
}
