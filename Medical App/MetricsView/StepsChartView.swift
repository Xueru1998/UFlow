import SwiftUI
import Charts

struct StepsChartView: View {
    @State private var stepsData: [(Date, Int)] = []
    @State private var currentDate = Date()
    @State private var dayOffset = 0

    var body: some View {
        VStack {
            Text("Steps for the Week")
                .font(.title)
                .padding(.top)

            // Bar Chart with a reduced frame height
            Chart {
                ForEach(stepsData, id: \.0) { data in
                    BarMark(
                        x: .value("Date", data.0),
                        y: .value("Steps", data.1)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 180)  // Reduced the height of the chart to 200 for better fit
            .padding(.horizontal) // Added padding for left and right edges
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 0 {
                            dayOffset -= 7
                        } else {
                            dayOffset += 7
                        }
                        updateStepsData()
                    }
            )

            HStack {
                Button("Previous Week") {
                    dayOffset -= 7
                    updateStepsData()
                }
                .padding()
                .foregroundColor(.purple)

                Spacer()

                Button("Next Week") {
                    dayOffset += 7
                    updateStepsData()
                }
                .padding()
                .foregroundColor(.purple)
            }
            .padding(.horizontal)  // Added padding for left and right buttons
        }
        .onAppear {
            updateStepsData()
        }
    }

    func updateStepsData() {
        let shiftedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: currentDate)!
        StepsDataFetcher.fetchSteps(forLastDays: 7, from: shiftedDate) { data in
            self.stepsData = data
        }
    }
}
