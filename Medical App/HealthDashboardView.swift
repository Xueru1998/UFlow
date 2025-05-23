import SwiftUI

struct HealthDashboardView: View {
    @State private var steps: String? = "Loading..."
    @State private var exerciseMinutes: String? = "Loading..."
    @State private var heartRate: String? = "Loading..."
    @State private var hrv: String? = "Loading..."
    @State private var bodyTemperature: String? = "Loading..."
    @State private var restingHeartRate: String? = "Loading..."
    @State private var sleepHours: String? = "Loading..."
    @State private var menstruationFlow: String? = "Loading..."
    
    @State private var heartRateTrend: [(Date, Int)] = []
    @State private var restingHeartRateTrend: [(Date, Int)] = []
    @State private var sleepTrend: [(Date, Double)] = []
    @State private var wristTemperatureTrend: [(Date, Double)] = []
    @State private var hrvTrend: [(Date, Int)] = []
    
    @State private var showHeartRateDetail = false
    
    var heartRateChange: String {
        return calculateChange(trend: heartRateTrend)
    }
    
    var restingHeartRateChange: String {
        return calculateChange(trend: restingHeartRateTrend)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("Health Dashboard")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            Text("Your daily health metrics at a glance")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                            Section {
                                NavigationLink(
                                    destination: SleepDetailView(),
                                    label: {
                                        ModernMetricCard(
                                            title: "Sleep",
                                            value: sleepHours ?? "Loading...",
                                            unit: "hours",
                                            trend: "Daily",
                                            icon: "bed.double.fill",
                                            iconColor: Color.blue,
                                            chartValues: sleepTrend.map { $0.1 },
                                            chartType: .bar
                                        )
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(
                                    destination: HeartRateDetailView(),
                                    label: {
                                        ModernMetricCard(
                                            title: "Heart Rate",
                                            value: heartRate ?? "Loading...",
                                            unit: "bpm",
                                            trend: heartRateChange,
                                            icon: "heart.fill",
                                            iconColor: Color.red,
                                            chartValues: heartRateTrend.map { Double($0.1) },
                                            chartType: .line
                                        )
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(
                                    destination: HRVDetailView(),
                                    label: {
                                        ModernMetricCard(
                                            title: "Heart Rate Variability",
                                            value: hrv ?? "Loading...",
                                            unit: "ms",
                                            trend: "Daily",
                                            icon: "waveform.path.ecg.rectangle.fill",
                                            iconColor: Color.purple,
                                            chartValues: hrvTrend.map { Double($0.1) },
                                            chartType: .line
                                        )
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(
                                    destination: RestingHeartRateDetailView(),
                                    label: {
                                        ModernMetricCard(
                                            title: "Resting Heart Rate",
                                            value: restingHeartRate ?? "Loading...",
                                            unit: "bpm",
                                            trend: restingHeartRateChange,
                                            icon: "heart.text.square.fill",
                                            iconColor: Color.pink,
                                            chartValues: restingHeartRateTrend.map { Double($0.1) },
                                            chartType: .line
                                        )
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                                
                                NavigationLink(
                                    destination: TemperatureDetailView(),
                                    label: {
                                        ModernMetricCard(
                                            title: "Wrist Temperature",
                                            value: bodyTemperature ?? "Loading...",
                                            unit: "°C",
                                            trend: "Daily",
                                            icon: "thermometer",
                                            iconColor: Color.orange,
                                            chartValues: wristTemperatureTrend.map { $0.1 },
                                            chartType: .line
                                        )
                                    }
                                )
                                .buttonStyle(PlainButtonStyle())
                                
                                ModernMetricCard(
                                    title: "Steps",
                                    value: steps ?? "Loading...",
                                    unit: "steps",
                                    trend: "Today",
                                    icon: "figure.walk.circle.fill",
                                    iconColor: Color.green,
                                    chartValues: [],
                                    chartType: .none
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                fetchHealthData()
            }
            .navigationBarHidden(true)
        }
    }
    
    func fetchHealthData() {
           
           // Fetch Steps
           StepsDataFetcher.fetchLatestSteps { data in
               DispatchQueue.main.async {
                   self.steps = data.isEmpty ? "0" : data // Update steps when fetched
               }
           }

           // Fetch Exercise Minutes
           ExerciseTimeDataFetcher.fetchLatestExerciseMinutes { data in
               DispatchQueue.main.async {
                   self.exerciseMinutes = data.isEmpty ? "0" : data
               }
           }
           
           let now = Date()

           // Fetch the latest heart rate (for the left side, current value)
           HeartRateDataFetcher.fetchHeartRateWithTimestamps(forLastDays: 1, from: now) { recentData in
                  DispatchQueue.main.async {
                      print("📱 Dashboard: Got recent heart rate data: \(recentData.count) records")
                      // Get the latest non-zero value for display
                      let validData = recentData.filter { $0.1 > 0 }
                      if let latest = validData.last {
                          self.heartRate = "\(Int(latest.1))"  // Set the latest heart rate for display
                          print("❤️ Dashboard: Updated heart rate to: \(self.heartRate ?? "unknown")")
                      } else {
                          // If no recent data, try getting data from the last 7 days
                          print("⚠️ Dashboard: No recent heart rate found, fetching older data...")
                          
                          HeartRateDataFetcher.fetchHeartRateWithTimestamps(forLastDays: 7, from: now) { olderData in
                              DispatchQueue.main.async {
                                  print("📱 Dashboard: Got older heart rate data: \(olderData.count) records")
                                  let validOlderData = olderData.filter { $0.1 > 0 }
                                  if let latestOlder = validOlderData.last {
                                      self.heartRate = "\(Int(latestOlder.1))"
                                      print("❤️ Dashboard: Updated heart rate to: \(self.heartRate ?? "unknown") from older data")
                                  } else {
                                      self.heartRate = "0"  // Fallback to 0 if no valid data
                                      print("⚠️ Dashboard: No heart rate data found at all")
                                  }
                              }
                          }
                      }
                  }
              }
             // Fetch daily average heart rate (for the right side, chart data)
             HeartRateDataFetcher.fetchDailyAverageHeartRate(forLastDays: 7, from: Date()) { data in
                 DispatchQueue.main.async {
                     self.heartRateTrend = data  // Set daily averages for chart visualization
                 }
             }

           // Fetch the latest HRV for display (left side)
           HRVDataFetcher.fetchHRVWithTimestamps(forLastDays: 7, from: Date()) { data in
               DispatchQueue.main.async {
                   let validData = data.filter { $0.1 > 0 }
                   if let latest = validData.last {  // Get the latest valid HRV value
                       self.hrv = "\(Int(latest.1))"  // Display as an integer
                   } else {
                       self.hrv = "0"  // Fallback if no valid data
                   }
               }
           }

           // Fetch daily average HRV for the trend chart (right side)
           HRVDataFetcher.fetchDailyAverageHRV(forLastDays: 7, from: Date()) { data in
               DispatchQueue.main.async {
                   self.hrvTrend = data  // Set daily averages for the chart
               }
           }

           WristTemperatureDataFetcher.fetchWristTemperatureWithTimestamps(forLastDays: 7, from: Date()) { data in
               DispatchQueue.main.async {
                   let validData = data.filter { $0.1 > 0 }
                   if let latest = validData.last {
                       self.bodyTemperature = String(format: "%.1f", latest.1)
                       print("Latest wrist temperature: \(String(format: "%.1f", latest.1))")
                   } else {
                       self.bodyTemperature = "0.0"
                   }
                   self.wristTemperatureTrend = data
               }
           }


           // Fetch the latest resting heart rate for display (left side)
           RestingHeartRateDataFetcher.fetchRestingHeartRateWithTimestamps(forLastDays: 7, from: Date()) { data in
               DispatchQueue.main.async {
                   let validData = data.filter { $0.1 > 0 }
                   if let latest = validData.last {  // Get the latest valid resting heart rate
                       self.restingHeartRate = "\(Int(latest.1))"  // Display as an integer
                   } else {
                       self.restingHeartRate = "0"  // Fallback if no valid data
                   }
               }
           }

           // Fetch daily average resting heart rate for the trend chart (right side)
           RestingHeartRateDataFetcher.fetchDailyAverageRestingHeartRate(forLastDays: 7, from: Date()) { data in
               DispatchQueue.main.async {
                   self.restingHeartRateTrend = data  // Set daily averages for the chart
               }
           }

           let calendar = Calendar.current
             var localCalendar = calendar
             localCalendar.timeZone = TimeZone.current

             let today = Date()
             let startOfToday = localCalendar.startOfDay(for: today)
             
             // For the single most recent sleep duration display
             let yesterdayEvening = localCalendar.date(byAdding: .hour, value: 20, to: localCalendar.date(byAdding: .day, value: -1, to: startOfToday)!)!
             let todayNoon = localCalendar.date(byAdding: .hour, value: 12, to: startOfToday)!
             
             // For the trend chart - get data for the past week
             let weekAgo = localCalendar.date(byAdding: .day, value: -7, to: startOfToday)!
             
             let sleepFetcher = SleepDataFetcher()
             
             sleepFetcher.requestAuthorization { success, error in
                 if success {
                     print("🛌 Sleep auth successful")
                     
                     // First, fetch data for the trend chart (whole week)
                     sleepFetcher.fetchSleepData(from: weekAgo, to: today) { weekPeriods in
                         DispatchQueue.main.async {
                             print("🛌 Received \(weekPeriods.count) sleep periods for the week")
                             
                             // Process each day separately for the trend chart
                             var dailySleepTrend: [(Date, Double)] = []
                             
                             // Go back 7 days and process each day
                             for dayOffset in -7..<0 {
                                 let targetDate = localCalendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
                                 let targetStartOfDay = localCalendar.startOfDay(for: targetDate)
                                 
                                 // Get evening before this day and noon of this day
                                 let eveningBefore = localCalendar.date(byAdding: .hour, value: 20, to: localCalendar.date(byAdding: .day, value: -1, to: targetStartOfDay)!)!
                                 let noonOfDay = localCalendar.date(byAdding: .hour, value: 12, to: targetStartOfDay)!
                                 
                                 print("🛌 Processing day: \(targetStartOfDay), window: \(eveningBefore) to \(noonOfDay)")
                                 
                                 // Filter periods that could be part of this day's sleep
                                 let dayPeriods = weekPeriods.filter {
                                     ($0.start >= eveningBefore && $0.start < noonOfDay) ||
                                     ($0.end > eveningBefore && $0.end <= noonOfDay)
                                 }
                                 
                                 if !dayPeriods.isEmpty {
                                     print("🛌 Found \(dayPeriods.count) periods for day \(targetStartOfDay)")
                                     
                                     // Sort periods by start time
                                     let sortedDayPeriods = dayPeriods.sorted { $0.start < $1.start }
                                     
                                     // Find first core sleep and last wake up for this day
                                     var firstSleep: (start: Date, end: Date)?
                                     var lastWakeUp: Date?
                                     
                                     for period in sortedDayPeriods {
                                         let startHour = localCalendar.component(.hour, from: period.start)
                                         let endHour = localCalendar.component(.hour, from: period.end)
                                         
                                         // First sleep that starts after 8 PM previous day or before noon
                                         if firstSleep == nil, (startHour >= 20 || startHour < 12) {
                                             firstSleep = period
                                         }
                                         
                                         // Last wake up before noon
                                         if endHour < 12 {
                                             lastWakeUp = period.end
                                         }
                                     }
                                     
                                     // Calculate duration if we found valid sleep session
                                     if let firstSleep = firstSleep, let lastWakeUp = lastWakeUp {
                                         let duration = lastWakeUp.timeIntervalSince(firstSleep.start) / 3600.0
                                         print("🛌 Day \(targetStartOfDay): Sleep duration \(duration) hours")
                                         dailySleepTrend.append((targetStartOfDay, duration))
                                     } else {
                                         print("🛌 Day \(targetStartOfDay): Couldn't determine valid sleep duration")
                                         dailySleepTrend.append((targetStartOfDay, 0.0))
                                     }
                                 } else {
                                     print("🛌 No sleep data for day \(targetStartOfDay)")
                                     dailySleepTrend.append((targetStartOfDay, 0.0))
                                 }
                             }
                             
                             // Sort trend data by date
                             let sortedTrend = dailySleepTrend.sorted { $0.0 < $1.0 }
                             self.sleepTrend = sortedTrend
                             
                             // Now find the most recent sleep duration for display
                             let todayPeriods = weekPeriods.filter {
                                 ($0.start >= yesterdayEvening && $0.start < todayNoon) ||
                                 ($0.end > yesterdayEvening && $0.end <= todayNoon)
                             }
                             
                             if !todayPeriods.isEmpty {
                                 let sortedTodayPeriods = todayPeriods.sorted { $0.start < $1.start }
                                 
                                 // Find first core sleep and last wake up
                                 var firstSleep: (start: Date, end: Date)?
                                 var lastWakeUp: Date?
                                 
                                 for period in sortedTodayPeriods {
                                     let startHour = localCalendar.component(.hour, from: period.start)
                                     let endHour = localCalendar.component(.hour, from: period.end)
                                     
                                     if firstSleep == nil, (startHour >= 20 || startHour < 12) {
                                         firstSleep = period
                                     }
                                     
                                     if endHour < 12 {
                                         lastWakeUp = period.end
                                     }
                                 }
                                 
                                 // Calculate today's sleep duration
                                 if let firstSleep = firstSleep, let lastWakeUp = lastWakeUp {
                                     let duration = lastWakeUp.timeIntervalSince(firstSleep.start) / 3600.0
                                     self.sleepHours = String(format: "%.1f", duration)
                                     print("🛌 Today's sleep: \(firstSleep.start) to \(lastWakeUp), Duration: \(duration) hours")
                                 } else {
                                     // If no valid sleep found for today, use the most recent day with data
                                     let daysWithData = sortedTrend.filter { $0.1 > 0 }
                                     if let mostRecentDay = daysWithData.last {
                                         self.sleepHours = String(format: "%.1f", mostRecentDay.1)
                                         print("🛌 Using most recent available sleep data: \(mostRecentDay.0), Duration: \(mostRecentDay.1) hours")
                                     } else {
                                         self.sleepHours = "0.0"
                                         print("🛌 No valid sleep data found")
                                     }
                                 }
                             } else {
                                 // If no periods found for today, use most recent data from trend
                                 let daysWithData = sortedTrend.filter { $0.1 > 0 }
                                 if let mostRecentDay = daysWithData.last {
                                     self.sleepHours = String(format: "%.1f", mostRecentDay.1)
                                     print("🛌 No data for today, using most recent available: \(mostRecentDay.0), Duration: \(mostRecentDay.1) hours")
                                 } else {
                                     self.sleepHours = "0.0"
                                     print("🛌 No valid sleep data found at all")
                                 }
                             }
                         }
                     }
                 } else {
                     print("🛌 Sleep authorization failed: \(String(describing: error?.localizedDescription))")
                 }
             }

           // Fetch Menstruation Flow
   //        MenstruationDataFetcher.fetchLatestMenstruationData { data in
   //            DispatchQueue.main.async {
   //                self.menstruationFlow = data.isEmpty ? "0.0" : data
   //            }
   //        }
       }
   }



func calculateChange(trend: [(Date, Int)]) -> String {
    guard trend.count > 1 else {
        return "No Change"
    }
    
    let latest = trend.last!.1
    let previous = trend[trend.count - 2].1
    let difference = latest - previous
    
    return difference >= 0 ? "+\(difference)" : "\(difference)"
}

enum ChartType {
    case line
    case bar
    case none
}

struct ModernMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: String
    let icon: String
    let iconColor: Color
    let chartValues: [Double]
    let chartType: ChartType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(value.isEmpty ? "No Data" : value)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                }
                
                HStack(spacing: 4) {
                    Text(trend)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if trend.hasPrefix("+") {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    } else if trend.hasPrefix("-") {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !chartValues.isEmpty {
                if chartType == .line {
                    ModernLineChart(values: chartValues, lineColor: iconColor)
                        .frame(height: 50)
                        .padding(.top, 4)
                } else if chartType == .bar {
                    ModernBarChart(values: chartValues, barColor: iconColor)
                        .frame(height: 50)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct ModernLineChart: View {
    let values: [Double]
    let lineColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue = values.max() ?? 1.0
            let minValue = max(0, values.min() ?? 0.0)
            let range = max(1, maxValue - minValue)
            
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, value) in values.enumerated() {
                            let xPosition = width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                            let yPosition = height * (1 - CGFloat((value - minValue) / range))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: xPosition, y: yPosition))
                            } else {
                                path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                            }
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                )
                
                Path { path in
                    for (index, value) in values.enumerated() {
                        let xPosition = width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                        let yPosition = height * (1 - CGFloat((value - minValue) / range))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: xPosition, y: yPosition))
                        } else {
                            path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                ForEach(0..<values.count, id: \.self) { index in
                    if index == values.count - 1 {
                        let value = values[index]
                        let xPosition = width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                        let yPosition = height * (1 - CGFloat((value - minValue) / range))
                        
                        Circle()
                            .fill(lineColor)
                            .frame(width: 6, height: 6)
                            .position(x: xPosition, y: yPosition)
                    }
                }
            }
        }
    }
}

struct ModernBarChart: View {
    let values: [Double]
    let barColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barSpacing: CGFloat = 2
            let barWidth = width / CGFloat(values.count) - barSpacing
            
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<values.count, id: \.self) { index in
                        let value = values[index]
                        let maxValue = values.max() ?? 1.0
                        let heightRatio = CGFloat(value / maxValue)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [barColor, barColor.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: max(4, heightRatio * height))
                            .opacity(value > 0 ? 1.0 : 0.3)
                    }
                }
            }
        }
    }
}
