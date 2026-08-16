import SwiftUI

struct WeeklyProgressCard: View {
    let status: BudgetEngine.WeeklyStatus

    private var progressColor: Color {
        if status.isOverLimit { return .red }
        if status.percentUsed >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Weekly Spending")
                        .font(.headline)
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if status.isOverLimit {
                    Label("Over Limit", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red, in: Capsule())
                }
            }

            ProgressView(value: min(status.percentUsed, 1))
                .tint(progressColor)

            HStack {
                Text("\(status.spent.formattedCurrency) spent")
                    .fontWeight(.medium)
                Spacer()
                Text(status.isOverLimit ? "\((-status.remaining).formattedCurrency) over" : "\(status.remaining.formattedCurrency) left")
                    .fontWeight(.medium)
                    .foregroundStyle(progressColor)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: -1, to: status.week.end) ?? status.week.end
        return "\(formatter.string(from: status.week.start)) – \(formatter.string(from: end))"
    }
}
