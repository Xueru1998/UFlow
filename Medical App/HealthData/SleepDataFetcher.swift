import HealthKit

class SleepDataFetcher {
    private let healthStore = HKHealthStore()

    // Request authorization to access sleep analysis data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(false, NSError(domain: "SleepDataFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sleep Analysis type is unavailable."]))
            return
        }

        let typesToRead: Set<HKObjectType> = [sleepType]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead, completion: completion)
    }

    // Fetch sleep data for a specific date range (considering 9 PM - 10 AM)
    func fetchSleepData(from startDate: Date, to endDate: Date, completion: @escaping ([(start: Date, end: Date)]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true) // ✅ Fix: Sort by start date
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, results, error) in
            if let error = error {
                print("❌ Error fetching sleep data: \(error.localizedDescription)")
                completion([])
                return
            }

            guard let samples = results as? [HKCategorySample] else {
                completion([])
                return
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current

          //  print("\n📊 Raw Sleep Data Fetched (Sorted by Start Time):")
//            for sample in samples {
//                print("   ⏳ Start: \(dateFormatter.string(from: sample.startDate))  |  🛌 End: \(dateFormatter.string(from: sample.endDate))")
//            }

            // ✅ Fix: Ensure start date is always before end date
            let validSamples = samples.filter { $0.startDate < $0.endDate }

            // ✅ Fix: Include all sleep states (not just core sleep)
            let relevantSamples = validSamples.filter { sample in
                let hour = Calendar.current.component(.hour, from: sample.startDate)
                return hour >= 20 || hour <= 11 // ✅ Adjust window from 8 PM to 11 AM
            }

            var sleepPeriods: [(start: Date, end: Date)] = []
            var sleepSessionStart: Date?
            var lastSleepEnd: Date?

            for sample in relevantSamples {
                let isSleepState = sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                                   sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue

                if isSleepState {
                    if sleepSessionStart == nil {
                        sleepSessionStart = sample.startDate // ✅ First detected sleep period
                    }
                    lastSleepEnd = sample.endDate // ✅ Track last detected sleep period
                } else if sleepSessionStart != nil {
                    // ✅ Finalize sleep session when awake state is detected
                    if let start = sleepSessionStart, let end = lastSleepEnd {
                        sleepPeriods.append((start, end))
                    }
                    sleepSessionStart = nil
                    lastSleepEnd = nil
                }
            }

            // ✅ Capture any remaining sleep session if it didn't end with "awake"
            if let start = sleepSessionStart, let end = lastSleepEnd {
                sleepPeriods.append((start, end))
            }

            // ✅ Fix: Sort sleep periods again by start time before returning
            sleepPeriods.sort(by: { $0.start < $1.start })

           // print("\n✅ Final Processed Sleep Periods:")
//            for period in sleepPeriods {
//                print("   😴 Sleep Start: \(dateFormatter.string(from: period.start))  |  ☀️ Wake Up: \(dateFormatter.string(from: period.end))")
//            }

            completion(sleepPeriods)
        }

        healthStore.execute(query)
    }

}
