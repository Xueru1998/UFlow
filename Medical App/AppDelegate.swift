import UIKit
import HealthKit
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate {

    var healthStore = HKHealthStore()
    private let sleepFetcher = SleepDataFetcher()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
           BGTaskScheduler.shared.register(forTaskWithIdentifier: "Uflow.healthSync", using: nil) { task in
               self.handleHealthSyncTask(task: task as! BGAppRefreshTask)
           }
           print("Application launched and background task registered")
           
           // Synchronize health data on launch
           fetchLatestHealthData { success in
               print("Health data sync on app launch completed with success: \(success)")
           }
           
           return true
       }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
            // Synchronize health data when app becomes active
            fetchLatestHealthData { success in
                print("Health data sync on app active completed with success: \(success)")
            }
        }


    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundHealthFetch()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        print("Application entered background, scheduling health fetch")
    }

    func scheduleBackgroundHealthFetch() {
        let request = BGAppRefreshTaskRequest(identifier: "com.example.healthSync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background health fetch scheduled")
        } catch {
            print("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    func handleHealthSyncTask(task: BGAppRefreshTask) {
        scheduleBackgroundHealthFetch()
        fetchLatestHealthData { success in
            task.setTaskCompleted(success: success)
            print("Background task completed with success: \(success)")
        }
    }

    func fetchLatestHealthData(completion: @escaping (Bool) -> Void) {
        let now = Date()
        let timeZone = TimeZone.current
        let calendar = Calendar.current
        
        // Create a dispatch group to coordinate all fetches
        let dispatchGroup = DispatchGroup()
        
        // Helper function to convert date to the desired timezone
        func convertToTimeZone(date: Date, timeZone: TimeZone) -> Date {
            let seconds = TimeInterval(timeZone.secondsFromGMT(for: date))
            return Date(timeInterval: seconds, since: date)
        }
        
        // Data containers
        var sleepData = [[String: Any]]()
        var hrvData = [String: [[String: Any]]]()
        var allSyncSuccess = true

        // Fetch sleep data
        dispatchGroup.enter()
        print("📋 STARTING SLEEP DATA FETCH")
        fetchAllSleepData { sleepRecords in
            print("✅ SLEEP DATA FETCH COMPLETE: Found \(sleepRecords.count) records")
            for record in sleepRecords {
                sleepData.append([
                    "date": record["date"] as? String ?? "",
                    "sleepStart": record["sleepStart"] as? String ?? "",
                    "wakeUp": record["wakeUp"] as? String ?? ""
                ])
            }
            dispatchGroup.leave()
        }
        
        // Fetch HRV data
        dispatchGroup.enter()
        print("💓 STARTING HRV DATA FETCH")
        let startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let hrvQuery = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            defer { dispatchGroup.leave() }
            if let error = error {
                print("❌ Error fetching HRV data: \(error.localizedDescription)")
                return
            }
            if let samples = samples as? [HKQuantitySample] {
                print("✅ HRV DATA FETCH COMPLETE: Found \(samples.count) records")
                for sample in samples {
                    let dateInTimeZone = convertToTimeZone(date: calendar.startOfDay(for: sample.startDate), timeZone: timeZone)
                    let timestampInTimeZone = convertToTimeZone(date: sample.startDate, timeZone: timeZone)

                    let localDateString = ISO8601DateFormatter().string(from: dateInTimeZone)
                    let timestampString = ISO8601DateFormatter().string(from: timestampInTimeZone)

                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

                    if hrvData[localDateString] != nil {
                        hrvData[localDateString]?.append(["timestamp": timestampString, "value": value])
                    } else {
                        hrvData[localDateString] = [["timestamp": timestampString, "value": value]]
                    }
                }
            } else {
                print("⚠️ No HRV samples found")
            }
        }
        healthStore.execute(hrvQuery)

        // First sync sleep and HRV data
        dispatchGroup.notify(queue: .main) {
            print("===== SYNCING SLEEP AND HRV DATA =====")
            
            // Format the data
            let formattedHRVData = hrvData.map { (date, values) -> [String: Any] in
                return ["date": date, "values": values]
            }
            
            // Create payload
            let initialHealthData: [String: Any] = [
                "hrvData": formattedHRVData,
                "sleepData": sleepData
            ]
            
            // Sync sleep and HRV data
            self.syncHealthDataToBackend(initialHealthData) { success in
                if !success {
                    allSyncSuccess = false
                    print("⚠️ Failed to sync sleep and HRV data")
                } else {
                    print("✅ Successfully synced sleep and HRV data")
                }
                
                // Now fetch and sync heart rate data day by day
                self.fetchAndSyncHeartRateDataByDay(from: startDate, to: now) { success in
                    if !success {
                        allSyncSuccess = false
                    }
                    completion(allSyncSuccess)
                }
            }
        }
    }

    // New function to fetch and sync heart rate data one day at a time
    func fetchAndSyncHeartRateDataByDay(from startDate: Date, to endDate: Date, completion: @escaping (Bool) -> Void) {
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        var currentDate = startDate
        var allSuccess = true
        
        // Helper function to convert date to the desired timezone
        func convertToTimeZone(date: Date, timeZone: TimeZone) -> Date {
            let seconds = TimeInterval(timeZone.secondsFromGMT(for: date))
            return Date(timeInterval: seconds, since: date)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        func processNextDay() {
            // If we've processed all days, we're done
            if currentDate > endDate {
                print("✅ ALL HEART RATE DATA SYNC COMPLETE")
                completion(allSuccess)
                return
            }
            
            // Define the day's start and end
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            print("❤️ FETCHING HEART RATE FOR: \(dateFormatter.string(from: dayStart))")
            
            // Create a container for this day's heart rate data
            var heartRateData = [String: [[String: Any]]]()
            
            // Create a predicate for this day only
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            // Fetch heart rate data for this day
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let heartRateQuery = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("❌ Error fetching heart rate data for \(dateFormatter.string(from: dayStart)): \(error.localizedDescription)")
                    // Move to next day even if this one failed
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    processNextDay()
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    print("ℹ️ No heart rate data found for \(dateFormatter.string(from: dayStart))")
                    // Move to next day
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    processNextDay()
                    return
                }
                
                print("📥 Received \(samples.count) heart rate samples for \(dateFormatter.string(from: dayStart))")
                
                // Process the samples
                for sample in samples {
                    let dateInTimeZone = convertToTimeZone(date: calendar.startOfDay(for: sample.startDate), timeZone: timeZone)
                    let timestampInTimeZone = convertToTimeZone(date: sample.startDate, timeZone: timeZone)
                    
                    let localDateString = ISO8601DateFormatter().string(from: dateInTimeZone)
                    let timestampString = ISO8601DateFormatter().string(from: timestampInTimeZone)
                    
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                    
                    if heartRateData[localDateString] != nil {
                        heartRateData[localDateString]?.append(["timestamp": timestampString, "value": value])
                    } else {
                        heartRateData[localDateString] = [["timestamp": timestampString, "value": value]]
                    }
                }
                
                // Format and sync this day's data
                let formattedHeartRateData = heartRateData.map { (date, values) -> [String: Any] in
                    return ["date": date, "values": values]
                }
                
                print("📊 Prepared \(formattedHeartRateData.count) day(s) of heart rate data with \(samples.count) readings")
                
                if !formattedHeartRateData.isEmpty {
                    // Sync just this day's heart rate data
                    let healthData: [String: Any] = [
                        "heartRateData": formattedHeartRateData
                    ]
                    
                    print("📤 SYNCING HEART RATE DATA FOR: \(dateFormatter.string(from: dayStart))")
                    
                    self.syncHealthDataToBackend(healthData) { success in
                        if !success {
                            allSuccess = false
                            print("❌ FAILED TO SYNC HEART RATE DATA FOR: \(dateFormatter.string(from: dayStart))")
                        } else {
                            print("✅ SUCCESSFULLY SYNCED HEART RATE DATA FOR: \(dateFormatter.string(from: dayStart))")
                        }
                        
                        // Move to next day
                        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                        processNextDay()
                    }
                } else {
                    // No data to sync, move to next day
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    processNextDay()
                }
            }
            
            healthStore.execute(heartRateQuery)
        }
        
        // Start processing days
        processNextDay()
    }

    // Enhanced sync function with better logging
    func syncHealthDataToBackend(_ healthData: [String: Any], completion: @escaping (Bool) -> Void) {
        print("===== STARTING HEALTH DATA SYNC =====")
        
        let metrics = [
            "stepsData",
            "heartRateData",
            "exerciseMinutesData",
            "bodyTemperatureData",
            "hrvData",
            "restingHeartRateData",
            "menstruationData",
            "sleepData"
        ]
        
        let dispatchGroup = DispatchGroup()
        var allSuccess = true
        var syncedMetrics: [String] = []
        
        for metric in metrics {
            if let data = healthData[metric] as? [[String: Any]], !data.isEmpty {
                dispatchGroup.enter()
                
                // Log when starting to sync a specific metric
                let recordCount = data.count
                print("📤 STARTING TO SYNC: \(metric) - Found \(recordCount) records")
                
                // For heart rate data, log more details
                if metric == "heartRateData" {
                    let totalReadings = data.reduce(0) { total, day in
                        total + ((day["values"] as? [[String: Any]])?.count ?? 0)
                    }
                    print("❤️ HEART RATE DATA: Starting to sync \(recordCount) days with \(totalReadings) total readings")
                    
                    // Log a sample to verify format
                    if let sampleDay = data.first, let dayValues = sampleDay["values"] as? [[String: Any]], let sampleValue = dayValues.first {
                        print("💡 HEART RATE SAMPLE: Day \(sampleDay["date"] ?? "unknown") - Sample value: \(sampleValue)")
                    }
                }
                
                let metricPayload: [String: Any] = [
                    "userId": healthData["userId"] as? String ?? "defaultUserId", // Use a default if not provided
                    "metricType": metric,
                    "data": data
                ]
                
                APIService.shared.syncHealthData(metricPayload) { result in
                    switch result {
                    case .success:
                        syncedMetrics.append(metric)
                        print("✅ SYNC COMPLETE: \(metric) successfully synced")
                        
                        if metric == "heartRateData" {
                            print("❤️ HEART RATE DATA: Successfully synced to backend")
                        }
                        
                    case .failure(let error):
                        print("❌ SYNC FAILED: \(metric) - Error: \(error.localizedDescription)")
                        allSuccess = false
                        
                        if metric == "heartRateData" {
                            print("⚠️ HEART RATE DATA: Failed to sync - \(error.localizedDescription)")
                        }
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("===== HEALTH DATA SYNC COMPLETED =====")
            if !syncedMetrics.isEmpty {
                print("✓ Successfully synced metrics: \(syncedMetrics.joined(separator: ", "))")
            } else {
                print("⚠️ No metrics were synced")
            }
            completion(allSuccess)
        }
    }

    func fetchAllSleepData(completion: @escaping ([[String: Any]]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        var sleepData: [[String: Any]] = [] // Stores formatted sleep data
        let group = DispatchGroup() // For handling async operations

        // Repeat for the last 4 weeks
        for weekOffset in 0...4 {
            let startOfWeek = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
            
            print("\n📆 Fetching sleep data for week starting from: \(formattedDate(startOfWeek))")

            for i in 0...6 {  // Loop through each day of the week
                let day = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
                
                // Define the fetching window for each day
                let startOfDay = calendar.startOfDay(for: day) // 12 AM of the day
                let startOfFetchWindow = calendar.date(byAdding: .hour, value: 20, to: calendar.date(byAdding: .day, value: -1, to: startOfDay)!)! // Fetch from 8 PM previous day
                let endOfFetchWindow = calendar.date(byAdding: .hour, value: 12, to: startOfDay)! // Fetch until 12 PM of the day

                print("🔍 Fetching sleep data for \(formattedDate(day)) from \(formattedTime(startOfFetchWindow)) to \(formattedTime(endOfFetchWindow))")

                group.enter() // Track async operation
                sleepFetcher.fetchSleepData(from: startOfFetchWindow, to: endOfFetchWindow) { periods in
                    DispatchQueue.main.async {
                        let sortedRecords = periods.sorted(by: { $0.start < $1.start })

                        var firstCoreSleep: (start: Date, end: Date)?
                        var lastWakeUp: Date?

                        for period in sortedRecords {
                            let startHour = calendar.component(.hour, from: period.start)
                            let endHour = calendar.component(.hour, from: period.end)

                            // ✅ Find the first valid sleep session (8 PM previous day or 12 AM - 12 PM current day)
                            if firstCoreSleep == nil, (startHour >= 20 || startHour < 12) {
                                firstCoreSleep = (start: period.start, end: period.end)
                            }

                            // ✅ Identify the last valid wake-up time (before 12 PM)
                            if endHour < 12 {
                                lastWakeUp = period.end
                            }
                        }

                        if let firstCoreSleep = firstCoreSleep, let lastWakeUp = lastWakeUp {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            formatter.timeZone = TimeZone.current  // Ensure correct timezone

                            let dateString = formatter.string(from: day)  // Ensures unique date string

                            let sleepStartString = ISO8601DateFormatter().string(from: firstCoreSleep.start)
                            let wakeUpString = ISO8601DateFormatter().string(from: lastWakeUp)

                            sleepData.append([
                                "date": dateString,
                                "sleepStart": sleepStartString,
                                "wakeUp": wakeUpString
                            ])
                        }

                        group.leave() // Mark async operation as done
                    }
                }
            }
        }

        group.notify(queue: .main) {  // Ensure all fetches complete before returning
            completion(sleepData)
        }
    }

    
    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
