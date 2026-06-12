import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: CostEntry

    var body: some View {
        if let data = entry.costData {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text("DeepSeek")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(entry.displayAmount(data.monthlyCost))
                    .font(.title.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                Text("本月消耗")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                HStack {
                    Text("💰 \(entry.displayAmount(data.totalBalance))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            errorView
        }
    }

    private var errorView: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(entry.error ?? "请配置 API Key")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}
