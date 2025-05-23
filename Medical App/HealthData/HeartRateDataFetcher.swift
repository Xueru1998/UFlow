import HealthKit

class HeartRateDataFetcher {
    static let healthStore = HKHealthStore()
    
    static func fetchDailyAverageHeartRate(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Int)]) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calendar = Calendar.current
        let endDate = date
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: startDate, intervalComponents: DateComponents(day: 1))
        
        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                completion([])
                return
            }
            
            var data: [(Date, Int)] = []
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let heartRate = statistics.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) ?? 0.0
                data.append((statistics.startDate, Int(heartRate)))
            }
            
            DispatchQueue.main.async {
                completion(data)
            }
        }
        
        healthStore.execute(query)
    }
    
    static func fetchHeartRateWithTimestamps(forLastDays days: Int, from date: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        let pageSize = 200
        var allData: [(Date, Double)] = []
        
        // Calculate the date range
        let calendar = Calendar.current
        let endDate = date
        
        // For prioritizing current day data
        let currentDayStart = calendar.startOfDay(for: date)
        let currentDayEnd = calendar.date(byAdding: .day, value: 1, to: currentDayStart)!
        
        // For historical data if needed
        let historicalStart = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        print("📊 Fetching heart rate data from \(historicalStart) to \(endDate)")
        print("🔍 Prioritizing current day: \(currentDayStart) to \(currentDayEnd)")
        
        // First, fetch current day data
        func fetchCurrentDayData(completion: @escaping () -> Void) {
            print("⚡️ Starting to fetch current day heart rate data...")
            let currentDayPredicate = HKQuery.predicateForSamples(
                withStart: currentDayStart,
                end: currentDayEnd,
                options: .strictStartDate
            )
            
            fetchDataWithPredicate(currentDayPredicate, isCurrentDay: true) {
                print("✅ Current day heart rate data fetch complete: \(allData.count) records")
                completion()
            }
        }
        
        // Then, fetch historical data if needed
        func fetchHistoricalData() {
            if days <= 1 {
                // Only current day was requested, we're done
                DispatchQueue.main.async {
                    completion(allData)
                }
                return
            }
            
            print("📚 Starting to fetch historical heart rate data...")
            let historicalPredicate = HKQuery.predicateForSamples(
                withStart: historicalStart,
                end: currentDayStart,
                options: .strictStartDate
            )
            
            fetchDataWithPredicate(historicalPredicate, isCurrentDay: false) {
                print("✅ Historical heart rate data fetch complete: total \(allData.count) records")
                DispatchQueue.main.async {
                    completion(allData)
                }
            }
        }
        
        // Generic function to fetch data with a given predicate
        func fetchDataWithPredicate(_ predicate: NSPredicate, isCurrentDay: Bool, completion: @escaping () -> Void) {
            func fetchPage(offset: Int = 0) {
                let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                                
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: pageSize,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        print("❌ Error fetching heart rate data: \(error.localizedDescription)")
                        if offset == 0 {
                            completion()
                        }
                        return
                    }
                    
                    guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                        print("ℹ️ No heart rate samples found for this page")
                        completion()
                        return
                    }
                    
                    
                    let pageData = samples.map { sample in
                        let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                        return (sample.startDate, heartRate)
                    }
                    
                    allData.append(contentsOf: pageData)
                    if samples.count == pageSize {
                        // Fetch next page
                        fetchPage(offset: offset + pageSize)
                    } else {
                        // No more data in this range
                        print("🏁 Reached end of data for this range")
                        completion()
                    }
                }
                
                HKHealthStore().execute(query)
            }
            
            fetchPage()
        }
        
        // Start the fetch sequence
        fetchCurrentDayData {
            fetchHistoricalData()
        }
    }
}
