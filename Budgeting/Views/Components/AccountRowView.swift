import SwiftUI

struct AccountRowView: View {
    let account: Account

    var body: some View {
        HStack {
            Image(systemName: account.type.systemImage)
                .foregroundStyle(Color(hex: account.colorHex))
                .frame(width: 28)

            VStack(alignment: .leading) {
                Text(account.name)
                Text(account.institution.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(account.balance.formattedCurrency)
                    .fontWeight(.medium)
                    .foregroundStyle(account.type == .creditCard && account.balance > 0 ? .red : .primary)
                if let limit = account.creditLimit {
                    Text("of \(limit.formattedCurrency) limit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
