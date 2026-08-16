import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.category.systemImage)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text(transaction.merchant)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.kind == .income ? "+\(transaction.amount.formattedCurrency)" : "-\(transaction.amount.formattedCurrency)")
                .foregroundStyle(transaction.kind == .income ? .green : .primary)
        }
    }
}
