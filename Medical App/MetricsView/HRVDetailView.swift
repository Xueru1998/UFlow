import SwiftUI
import Charts

enum ViewMode {
    case daily, weekly
}

struct HRVDetailView: View {
    @State private var dailyHRVData: [(String, Double)] = []  // [(Timestamp, HRV Value)]
    @State private var selectedDate: Date = Date()  // Track the selected date
    @State private var viewMode: ViewMode = .weekly  // Track the current view mode (Weekly)
    @State private var selectedHRV: (String, Double)? = nil  // Store the selected HRV data point
    
    var body: some View {
        let curColor = Color.blue
        let curGradient = LinearGradient(
            gradient: Gradient(colors: [curColor.opacity(0.5), curColor.opacity(0.2), curColor.opacity(0.05)]),
            startPoint: .top,
            endPoint: .bottom
        )

        VStack {
            // Weekly or Daily Picker
            Picker("View Mode", selection: $viewMode) {
                Text("Daily").tag(ViewMode.daily)
                Text("Weekly").tag(ViewMode.weekly)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: viewMode) { _ in
                fetchHRVData(for: selectedDate)
            }

            // Date Picker
            HStack {
                Button(action: {
                    if viewMode == .daily {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? Date()
                    } else {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? Date()
                    }
                    fetchHRVData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                Spacer()

                Text(viewMode == .daily ? formattedDate(selectedDate) : formattedWeekRange(for: selectedDate))
                    .font(.headline)
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    if viewMode == .daily {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date()
                    } else {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? Date()
                    }
                    fetchHRVData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .padding()

            if dailyHRVData.isEmpty {
                Text("No Data Available")
                    .font(.title2)
                    .padding()
            } else {
                GroupBox("HRV Over Time") {
                    ZStack {
                        Chart {
                            // Current Data - Line + Area (for both daily and weekly)
                            ForEach(dailyHRVData.indices, id: \.self) { index in
                                LineMark(
                                    x: .value("Date", dailyHRVData[index].0),
                                    y: .value("HRV", dailyHRVData[index].1)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(curColor)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .symbol {
                                    Circle()
                                        .fill(curColor)
                                        .frame(width: 10)
                                }

                                AreaMark(
                                    x: .value("Date", dailyHRVData[index].0),
                                    y: .value("HRV", dailyHRVData[index].1)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(curGradient)
                            }
                        }
                        .frame(height: 300)
                        .chartLegend(position: .top, alignment: .leading)
                        .chartPlotStyle { plotArea in
                            plotArea.background(Color.white.opacity(0.1))
                        }

                        // Add an overlay for tap detection
                        GeometryReader { geometry in
                            Rectangle()
                                .foregroundColor(Color.clear)
                                .contentShape(Rectangle()) // Enable tap detection for the entire area
                                .onTapGesture { location in
                                    let totalWidth = geometry.size.width
                                    let stepWidth = totalWidth / CGFloat(dailyHRVData.count)

                                    // Calculate the index of the tapped data point
                                    let index = Int((location.x / totalWidth) * CGFloat(dailyHRVData.count))
                                    if index >= 0 && index < dailyHRVData.count {
                                        selectedHRV = dailyHRVData[index]
                                    }
                                }
                        }
                    }
                }
                .padding()


                // Show detailed information card for the selected HRV data point
                if let selected = selectedHRV {
                    VStack(alignment: .leading) {
                        Text("Detailed HRV Data")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        Text("Time: \(selected.0)")
                            .font(.subheadline)

                        Text("HRV Value: \(Int(selected.1)) ms")
                            .font(.subheadline)

                        if let previousIndex = dailyHRVData.firstIndex(where: { $0.0 == selected.0 }), previousIndex > 0 {
                            let previousHRV = dailyHRVData[previousIndex - 1]
                            let change = calculatePercentageChange(from: previousHRV.1, to: selected.1)
                            Text("Change from previous: \(String(format: "%.2f", change))%")
                                .font(.subheadline)
                                .foregroundColor(change >= 0 ? .green : .red)
                            Text("Compared to previous at \(previousHRV.0)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding()
                }
            }
        }
        .onAppear {
            fetchHRVData(for: selectedDate)
        }
    }

    // Fetch HRV data based on the current view mode
    func fetchHRVData(for date: Date) {
        if viewMode == .daily {
            fetchDailyHRVData(for: date)
        } else {
            fetchWeeklyHRVData(for: date)
        }
    }

    func fetchDailyHRVData(for date: Date) {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? Date()

           // Fetch data for the current day
           HRVDataFetcher.fetchHRVWithTimestamps(forLastDays: 1, from: date) { currentDayData in
               // Fetch data for the next day
               HRVDataFetcher.fetchHRVWithTimestamps(forLastDays: 1, from: nextDay) { nextDayData in

                   // Combine both sets of data
                   let combinedData = currentDayData + nextDayData

                   // Filter data to include only entries from the selected day
                   let filteredData = combinedData.filter { isSameMonthAndDay($0.0, as: date) }

                   // Group the data by hour
                   let groupedData = groupHRVByHour(filteredData, for: date)
                   DispatchQueue.main.async {
                       self.dailyHRVData = groupedData
                   }
               }
           }
       }
    
    func fetchWeeklyHRVData(for date: Date) {
        // Fetch weekly HRV data logic
        HRVDataFetcher.fetchHRVWithTimestamps(forLastDays: 7, from: date) { data in
            let filteredData = data.filter { isDate($0.0, inSameWeekAs: date) }
            let groupedData = groupHRVByDay(filteredData, for: date)
            DispatchQueue.main.async {
                self.dailyHRVData = groupedData
            }
        }
    }

    func groupHRVByDay(_ data: [(Date, Double)], for date: Date) -> [(String, Double)] {
        var groupedData: [String: [Double]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E"  // Use abbreviated weekday names (e.g., Mon, Tue)

        // Group HRV data by day of the week
        for (dataDate, hrv) in data {
            let dayString = dateFormatter.string(from: dataDate)
            groupedData[dayString, default: []].append(hrv)
        }

        // Calculate the average HRV for each day
        var result: [(String, Double)] = []
        for (day, hrvs) in groupedData {
            let averageHRV = hrvs.reduce(0, +) / Double(hrvs.count)
            result.append((day, averageHRV))
        }

        // Sort by predefined weekday order
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        result.sort { (day1, day2) -> Bool in
            return weekdays.firstIndex(of: day1.0)! < weekdays.firstIndex(of: day2.0)!
        }

        return result
    }

    func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: date)
    }

    func formattedWeekRange(for date: Date) -> String {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        return "\(dateFormatter.string(from: weekStart)) - \(dateFormatter.string(from: weekEnd))"
    }
}





    // Helper function to check if dates are in the same week
    func isDate(_ date1: Date, inSameWeekAs date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, equalTo: date2, toGranularity: .weekOfYear)
    }


 
    
func groupHRVByHour(_ data: [(Date, Double)], for date: Date) -> [(String, Double)] {
    var groupedData: [String: [Double]] = [:]
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"  // Use hour and minute for chart display

    for (dataDate, hrv) in data {
        if isSameMonthAndDay(dataDate, as: date) {
            let timeString = dateFormatter.string(from: dataDate)
            groupedData[timeString, default: []].append(hrv)
        }
    }

    // Average the HRV values if there are multiple entries in one minute
    var result: [(String, Double)] = []
    for (time, hrvs) in groupedData {
        let averageHRV = hrvs.reduce(0, +) / Double(hrvs.count)
        result.append((time, averageHRV))
    }

    // Sort by time for better display
    return result.sorted { $0.0 < $1.0 }
}

    
    // Calculate the percentage change compared to the previous HRV value
    func calculatePercentageChange(from previousValue: Double, to currentValue: Double) -> Double {
        return ((currentValue - previousValue) / previousValue) * 100
    }
    
    // Check if two dates have the same month and day
    func isSameMonthAndDay(_ date1: Date, as date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.month, .day], from: date1)
        let components2 = calendar.dateComponents([.month, .day], from: date2)
        return components1.month == components2.month && components1.day == components2.day
    }
    
    
    // Format the date for display
       func formattedDate(_ date: Date) -> String {
           let dateFormatter = DateFormatter()
           dateFormatter.dateStyle = .medium
           return dateFormatter.string(from: date)
       }
       
       // Helper to detect the tapped point on the chart
       func getTappedPoint(location: CGPoint, in data: [(String, Double)]) -> (index: Int, data: (String, Double))? {
           // For simplicity, assume each point takes an equal horizontal space
           let totalWidth = UIScreen.main.bounds.width - 40  // Same width as chart form
           let step = totalWidth / CGFloat(data.count)
           let index = Int(location.x / step)
           
           if index >= 0 && index < data.count {
               return (index, data[index])
           }
           return nil
       }
       
       // Helper function to format the week range for display
       func formattedWeekRange(for date: Date) -> String {
           let calendar = Calendar.current
           let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
           let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
           
           let dateFormatter = DateFormatter()
           dateFormatter.dateFormat = "MMM d"
           
           return "\(dateFormatter.string(from: weekStart)) - \(dateFormatter.string(from: weekEnd))"
       }
   
