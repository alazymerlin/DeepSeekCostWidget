import SwiftUI
import WidgetKit
import Charts

struct LargeWidgetView: View {
    let entry: CostEntry

    var body: some View {
        if let data = entry.costData {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Label("DeepSeek", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Text(L10n.refresh)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 两个大数字
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.monthlyCost))
                            .font(.title.bold().monospacedDigit())
                            .foregroundColor(.accentColor)
                        Text(L10n.monthlyCost)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.todayCost))
                            .font(.title.bold().monospacedDigit())
                            .foregroundColor(.accentColor)
                        Text(L10n.todayCost)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 14天趋势图
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.trend14Days)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Chart(data.dailyCosts) { dc in
                        BarMark(
                            x: .value("日期", dc.date),
                            y: .value("费用", dc.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { _ in
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }
                    .frame(height: 80)
                }

                // 模型分布
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.modelDistribution)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(data.modelCosts) { mc in
                        let barPct = min(mc.amount * 10, 100)
                        VStack(spacing: 3) {
                            HStack {
                                Text(mc.displayName)
                                    .font(.caption)
                                Spacer()
                                Text(entry.displayAmount(mc.amount))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.accentColor)
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.5))
                                    .frame(width: geo.size.width * barPct / 100)
                            }
                            .frame(height: 6)
                        }
                    }
                }

                // Footer
                HStack {
                    Text("💰 余额 \(entry.displayAmount(data.totalBalance))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(L10n.updated) \(formatTime(data.lastUpdated))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: entry.error != nil ? "exclamationmark.triangle.fill" : "key.fill")
                    .font(.title)
                    .foregroundColor(entry.error != nil ? .orange : .accentColor)
                Text(entry.error ?? L10n.noAPIKey)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text(L10n.openAppToConfig)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
