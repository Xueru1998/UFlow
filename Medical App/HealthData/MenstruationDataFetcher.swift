import HealthKit

class MenstruationDataFetcher {
    static func fetchLatestMenstruationData(completion: @escaping (String) -> Void) {
        let healthStore = HKHealthStore()
        let menstrualFlowType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!
        let startDate = Calendar.current.date(byAdding: .day, value: -28, to: Date())!

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(sampleType: menstrualFlowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                completion("")
                return
            }

            var latestFlowLevel: Double = 0.0
            if let latestSample = samples.last {
                latestFlowLevel = Double(latestSample.value)
            }

            DispatchQueue.main.async {
                completion("\(latestFlowLevel)")
            }
        }

        healthStore.execute(query)
    }
}
