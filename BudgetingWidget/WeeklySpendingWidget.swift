import WidgetKit
import SwiftUI
import SwiftData

struct WeeklySpendingEntry: TimelineEntry {
    let date: Date
    let status: BudgetEngine.WeeklyStatus
}

struct WeeklySpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklySpendingEntry {
        let week = BudgetEngine.weekInterval(containing: .now, weekStartsMonday: true)
        return WeeklySpendingEntry(date: .now, status: .init(week: week, limit: 300, spent: 120))
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklySpendingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklySpendingEntry>) -> Void) {
        let entry = currentEntry()
        // Spending data only changes when the user logs a transaction in-app, so hourly
        // refreshes are enough to keep the widget's numbers current.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? Date.now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    @MainActor
    private func currentEntry() -> WeeklySpendingEntry {
        let context = SharedModelContainer.shared.mainContext
        let settings = (try? context.fetch(FetchDescriptor<BudgetSettings>()))?.first ?? BudgetSettings()
        let charges = (try? context.fetch(FetchDescriptor<RecurringCharge>())) ?? []
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let status = BudgetEngine.weeklyStatus(settings: settings, fixedCharges: charges, transactions: transactions)
        return WeeklySpendingEntry(date: .now, status: status)
    }
}

struct WeeklySpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeeklySpendingEntry

    private var progressColor: Color {
        if entry.status.isOverLimit { return .red }
        if entry.status.percentUsed >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(entry.status.percentUsed, 1)) {
                Text("Wk")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(progressColor)

        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                Text("This Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Gauge(value: min(entry.status.percentUsed, 1)) {
                    Text("Spent")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(progressColor)
                .frame(maxWidth: .infinity, alignment: .center)
                Text(entry.status.spent.formattedCurrency)
                    .font(.headline)
                Text("of \(entry.status.limit.formattedCurrency)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()

        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Spending")
                    .font(.headline)
                ProgressView(value: min(entry.status.percentUsed, 1))
                    .tint(progressColor)
                HStack {
                    Text("\(entry.status.spent.formattedCurrency) spent")
                    Spacer()
                    Text(entry.status.isOverLimit ? "\((-entry.status.remaining).formattedCurrency) over" : "\(entry.status.remaining.formattedCurrency) left")
                        .foregroundStyle(progressColor)
                }
                .font(.subheadline)
            }
            .padding()
        }
    }
}

struct WeeklySpendingWidget: Widget {
    let kind = "WeeklySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklySpendingProvider()) { entry in
            WeeklySpendingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Spending")
        .description("Track this week's spending against your budget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
