import SwiftUI
import SwiftUICharts

struct RestingHeartRateLineChart: View {
    let heartRateData: [(String, Double)]  // [(Weekday, Resting Heart Rate in BPM)]
    @Binding var selectedDataPoint: (String, Double)?  // For showing the selected heart rate

    var body: some View {
        VStack {
            LineChartView(
                data: heartRateData.map { $0.1 },
                title: "Resting Heart Rate",
                legend: "Week",
                style: ChartStyle(
                    backgroundColor: Color.white,
                    accentColor: Color.red,
                    gradientColor: GradientColors.blue,
                    textColor: Color.black,
                    legendTextColor: Color.gray,
                    dropShadowColor: Color.gray.opacity(0.5)
                ),
                form: CGSize(width: UIScreen.main.bounds.width - 40, height: 200),
                rateValue: nil,
                valueSpecifier: "%.0f BPM"
            )

            HStack {
                ForEach(0..<heartRateData.count, id: \.self) { index in
                    let day = heartRateData[index].0
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}



struct RestingHeartRateDetailView: View {
    @State private var weeklyHeartRateData: [(String, Double)] = []
    @State private var selectedHeartRate: (String, Double)? = nil  // Store the selected heart rate point
    @State private var selectedDate: Date = Date()  // Track the selected date

    var body: some View {
        VStack {
            // Date navigation
            HStack {
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
                    fetchHeartRateData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding()
                }

                Text("\(formattedWeekRange(for: selectedDate))")
                    .font(.headline)

                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
                    fetchHeartRateData(for: selectedDate)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding()
                }
            }
            .padding(.bottom)

            // Line chart using SwiftUICharts
            RestingHeartRateLineChart(heartRateData: weeklyHeartRateData, selectedDataPoint: $selectedHeartRate)
                .frame(height: 300)  // Adjust the height as needed

            Spacer()

            // Display selected heart rate details when tapped (if interactivity is added)
            if let selected = selectedHeartRate {
                VStack(alignment: .leading) {
                    Text("Resting Heart Rate: \(String(format: "%.0f", selected.1)) BPM")
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
            fetchHeartRateData(for: selectedDate)
        }
    }

    // Fetch resting heart rate data for the past 7 days
    func fetchHeartRateData(for date: Date) {
        RestingHeartRateDataFetcher.fetchDailyAverageRestingHeartRate(forLastDays: 7, from: date) { data in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE"  // Format as a short weekday name

            let formattedData = data.map { (date, hr) -> (String, Double) in
                let weekday = dateFormatter.string(from: date)
                return (weekday, Double(hr))
            }

            DispatchQueue.main.async {
                self.weeklyHeartRateData = formattedData
            }
        }
    }

    // Helper function to format the week range
    func formattedWeekRange(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        return "\(dateFormatter.string(from: startOfWeek)) - \(dateFormatter.string(from: endOfWeek))"
    }
}
