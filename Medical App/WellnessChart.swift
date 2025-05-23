import SwiftUI

struct WellnessChart: View {
    let data: [(date: Date, value: Double)]

    var body: some View {
        VStack {
            Text("Wellness Chart")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            // Placeholder for the wellness chart (replace with an actual chart)
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.4)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(height: 150)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}
