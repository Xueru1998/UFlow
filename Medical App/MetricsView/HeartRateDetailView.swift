import SwiftUI
import Charts

struct HeartRateData: Identifiable {
    let id = UUID()
    let hour: Int
    let minRate: Int
    let maxRate: Int
}

struct HeartRateDetailView: View {
    @State private var hourlyHeartRateData: [HeartRateData] = []
    @State private var selectedHeartRateRange: HeartRateData? = nil
    @State private var selectedDate: Date = Date()
    @State private var selectedHour: Int? = nil  // For tracking the selected bar in the chart

    var body: some View {
        VStack {
            // Date picker with left and right arrows
            HStack {
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? Date()
                    fetchHeartRateData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                Spacer()

                Text(formattedDate(selectedDate))
                    .font(.headline)
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date()
                    fetchHeartRateData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .padding()

            if hourlyHeartRateData.isEmpty {
                Text("No Data Available")
                    .font(.title2)
                    .padding()
            } else {
                Text("RANGE")
                    .font(.headline)
                    .padding(.top)

                Text("\(hourlyHeartRateData.map { $0.minRate }.min() ?? 0)-\(hourlyHeartRateData.map { $0.maxRate }.max() ?? 0) BPM")
                    .font(.system(size: 40, weight: .bold))

            

                // Swift Charts bar chart for heart rate data
                HourlyHeartRateBarChart(
                    hourlyData: hourlyHeartRateData,
                    selectedHeartRateRange: $selectedHeartRateRange,
                    selectedHour: $selectedHour
                )
                .frame(height: 200)
                .padding(.top, 50)

                Spacer()

                // Display the selected bar's heart rate details when a bar is tapped
                if let selectedRange = selectedHeartRateRange {
                    VStack(alignment: .leading) {
                        Text("\(selectedRange.minRate)-\(selectedRange.maxRate) BPM")
                            .font(.headline)
                            .padding(.top)

                        Text("Date: \(formattedDate(selectedDate)), \(selectedRange.hour):00 - \(selectedRange.hour):59")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                // Latest heart rate value
                if let latest = hourlyHeartRateData.last {
                    HStack {
                        Text("Latest: \(latest.hour):00")
                        Spacer()
                        Text("\(latest.maxRate) BPM")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            fetchHeartRateData(for: selectedDate)
        }
    }

    func fetchHeartRateData(for date: Date) {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? Date()

        // Fetch data for the current day
        HeartRateDataFetcher.fetchHeartRateWithTimestamps(forLastDays: 1, from: date) { currentDayData in
            // Fetch data for the next day
            HeartRateDataFetcher.fetchHeartRateWithTimestamps(forLastDays: 1, from: nextDay) { nextDayData in

                // Combine both sets of data
                let combinedData = currentDayData + nextDayData

                // Filter data to include only entries from the selected day
                let filteredData = combinedData.filter { isSameMonthAndDay($0.0, as: date) }

                let groupedData = groupHeartRateByHour(filteredData, for: date)
                DispatchQueue.main.async {
                    self.hourlyHeartRateData = groupedData
                }
            }
        }
    }

    func groupHeartRateByHour(_ data: [(Date, Double)], for date: Date) -> [HeartRateData] {
        var groupedData: [Int: [Double]] = [:]
        let calendar = Calendar.current

        // Group heart rate by hour for the selected day only
        for (dataDate, heartRate) in data {
            if isSameMonthAndDay(dataDate, as: date) {
                let hour = calendar.component(.hour, from: dataDate)
                groupedData[hour, default: []].append(heartRate)
            }
        }

        // Create HeartRateData instances
        var result: [HeartRateData] = []
        for (hour, heartRates) in groupedData {
            let minRate = Int(heartRates.min() ?? 0)
            let maxRate = Int(heartRates.max() ?? 0)
            result.append(HeartRateData(hour: hour, minRate: minRate, maxRate: maxRate))
        }

        // Sort by hour for better display
        return result.sorted { $0.hour < $1.hour }
    }

    func isSameMonthAndDay(_ date1: Date, as date2: Date) -> Bool {
        let calendar = Calendar.current
        let components1 = calendar.dateComponents([.year, .month, .day], from: date1)
        let components2 = calendar.dateComponents([.year, .month, .day], from: date2)
        return components1.year == components2.year && components1.month == components2.month && components1.day == components2.day
    }

    func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter.string(from: date)
    }
}

struct HourlyHeartRateBarChart: View {
    let hourlyData: [HeartRateData]
    @Binding var selectedHeartRateRange: HeartRateData?
    @Binding var selectedHour: Int?

    var body: some View {
        Chart {
            ForEach(hourlyData) { data in
                BarMark(
                    x: .value("Hour", data.hour),
                    yStart: .value("Min Rate", data.minRate),
                    yEnd: .value("Max Rate", data.maxRate)
                )
                .foregroundStyle(selectedHour == data.hour ? Color.blue.gradient : Color.red.gradient)
            }
        }
        .chartYScale(domain: 40...180)  // Adjust the Y-axis domain to 40...180
        .chartXScale(domain: 0...23)  // X-axis domain remains the same (0 to 23 hours)
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, through: 23, by: 1))) { value in
                if let hour = value.as(Int.self), hour % 6 == 0 {
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(hour)")
                    }
                } else {
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [40, 100, 180]) { value in  // Adjust the AxisMarks to match your new range
                AxisGridLine()
                AxisValueLabel {
                    Text("\(value.as(Int.self) ?? 0)")
                }
            }
        }
        // Use chartOverlay to detect taps
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let location = value.location
                                if let hour: Int = proxy.value(atX: location.x) {
                                    // Find the data for the tapped hour
                                    if let data = hourlyData.first(where: { $0.hour == hour }) {
                                        selectedHeartRateRange = data
                                        selectedHour = hour
                                    }
                                }
                            }
                    )
            }
        }
    }
}

