import SwiftUI

struct SleepDetailView: View {
    @State private var selectedDate: Date = Date()  // Represents the current week.
    @State private var sleepData: [(date: Date, sleepStart: Date, wakeUp: Date)] = []
    @State private var sleepHours: String = "0.0"

    private let sleepFetcher = SleepDataFetcher()

    var localCalendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current  // ✅ Adjust for user's timezone
        cal.firstWeekday = 2  // Monday as the first day of the week
        return cal
    }()

    var body: some View {
        VStack {
            Text("Weekly Sleep Data")
                .font(.headline)
                .padding(.top)

            HStack {
                Button(action: {
                    if let newDate = localCalendar.date(byAdding: .day, value: -7, to: self.selectedDate) {
                        self.selectedDate = newDate
                        self.fetchWeeklySleepData()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding()
                }

                Text(formattedWeekRange(for: self.selectedDate))
                    .font(.headline)

                Button(action: {
                    if let newDate = localCalendar.date(byAdding: .day, value: 7, to: self.selectedDate) {
                        self.selectedDate = newDate
                        self.fetchWeeklySleepData()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding()
                }
            }
            .padding(.bottom)

            if sleepData.isEmpty {
                Text("No sleep data available for this week")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(sleepData, id: \.date) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(formattedDate(record.date))")
                                .font(.headline)
                            Text("😴 Sleep Start: \(formattedTime(record.sleepStart))")
                                .foregroundColor(.blue)
                            Text("☀️ Get Up: \(formattedDate(record.wakeUp)) - \(formattedTime(record.wakeUp))")
                                .foregroundColor(.green)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                }
            }

            Spacer()

            Text("Total Sleep This Week: \(sleepHours) hours")
                .padding()
        }
        .onAppear {
            sleepFetcher.requestAuthorization { success, error in
                if success {
                    self.fetchWeeklySleepData()
                } else {
                    print("Authorization failed: \(String(describing: error?.localizedDescription))")
                }
            }
        }
    }

    /// Fetch sleep data for the selected week
    func fetchWeeklySleepData() {
        let calendar = localCalendar
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self.selectedDate))!
        
        var weeklyData: [(Date, Date, Date)] = [] // (Date, Sleep Start, Wake Up)

        let group = DispatchGroup() // To handle multiple async fetches

        for i in 0...6 {  // Loop through each day of the week
            let day = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            
            // Define start and end of fetching window per day
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
                        weeklyData.append((day, firstCoreSleep.start, lastWakeUp))

                        print("\n✅ Finalized Sleep Record for \(formattedDate(day)):")
                        print("   😴 Sleep Start: \(formattedTime(firstCoreSleep.start))")
                        print("   ☀️ Get Up: \(formattedTime(lastWakeUp))")
                    }

                    group.leave() // Mark async operation as done
                }
            }
        }

        group.notify(queue: .main) {  // Ensure all fetches complete before updating UI
            self.sleepData = weeklyData.sorted { $0.0 < $1.0 }
            self.sleepHours = String(format: "%.1f", weeklyData.reduce(0) { $0 + $1.2.timeIntervalSince($1.1) / 3600.0 })
        }
    }



    /// Format week range for display (e.g., "Mar 4 - Mar 10")
    func formattedWeekRange(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone.current

        let startOfWeek = localCalendar.date(from: localCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let endOfWeek = localCalendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }

    /// Convert Date to Full Date (e.g., "March 4, 2024")
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Convert Date to Short Time (e.g., "10:30 PM")
    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
