import SwiftUI
import SwiftUICharts


struct WristTemperatureLineChart: View {
    let temperatureData: [(String, Double)]  // [(Weekday, Temperature in °C)]
    @Binding var selectedDataPoint: (String, Double)?  // For showing the selected temperature

    var body: some View {
        VStack {
            LineChartView(data: temperatureData.map { $0.1 },
                          title: "Wrist Temperature",
                          legend: "Week",
                          style: ChartStyle(backgroundColor: .white,
                                            accentColor: .blue,
                                            gradientColor: GradientColors.blue,
                                            textColor: .black,
                                            legendTextColor: .gray,
                                            dropShadowColor: .gray.opacity(0.5)),
                          form: CGSize(width: UIScreen.main.bounds.width - 40, height: 200),
                          rateValue: nil, 
                          valueSpecifier: "%.2f°C")
            
            HStack {
                ForEach(0..<temperatureData.count, id: \.self) { index in
                    let day = temperatureData[index].0
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TemperatureDetailView: View {
    @State private var weeklyTemperatureData: [(String, Double)] = []
    @State private var selectedTemperature: (String, Double)? = nil  // Store the selected temperature point
    @State private var selectedDate: Date = Date()  // Track the selected date

    var body: some View {
        VStack {
            // Date navigation
            HStack {
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
                    fetchTemperatureData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding()
                }

                Text("\(formattedWeekRange(for: selectedDate))")
                    .font(.headline)

                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
                    fetchTemperatureData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding()
                }
            }
            .padding(.bottom)

            // Line chart using SwiftUICharts
            WristTemperatureLineChart(temperatureData: weeklyTemperatureData, selectedDataPoint: $selectedTemperature)
                .frame(height: 300)  // Adjust the height as needed
            
            Spacer()

            // Display selected temperature details when tapped
            if let selected = selectedTemperature {
                VStack(alignment: .leading) {
                    Text("Temperature: \(String(format: "%.2f", selected.1)) °C")
                        .font(.headline)
                        .padding(.top)
                    Text("Day: \(selected.0)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Spacer()
        }
        .onAppear {
            fetchTemperatureData(for: selectedDate)
        }
    }

    // Fetch wrist temperature data for the past 7 days
    func fetchTemperatureData(for date: Date) {
        WristTemperatureDataFetcher.fetchWristTemperatureWithTimestamps(forLastDays: 7, from: date) { data in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE"  // Format as a short weekday name

            let formattedData = data.map { (date, temp) -> (String, Double) in
                let weekday = dateFormatter.string(from: date)
                return (weekday, temp)
            }
            
            DispatchQueue.main.async {
                self.weeklyTemperatureData = formattedData
            }
        }
    }

    // Helper function to format the week range
    func formattedWeekRange(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return "\(dateFormatter.string(from: startOfWeek)) - \(dateFormatter.string(from: endOfWeek))"
    }
}
