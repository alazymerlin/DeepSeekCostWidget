import SwiftUI
import WidgetKit
import Charts

struct LargeWidgetView: View {
    let entry: CostEntry

    var body: some View {
        if let data = entry.costData {
            VStack(spacing: 12) {
                HStack {
                    Label("DeepSeek", systemImage: "chart.bar.fill").font(.headline).foregroundColor(.accentColor)
                    Spacer()
                    
                }
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.monthlyCost)).font(.title.bold().monospacedDigit()).foregroundColor(.accentColor)
                        Text(L10n.monthlyCost).font(.caption).foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.todayCost)).font(.title.bold().monospacedDigit()).foregroundColor(.accentColor)
                        Text(L10n.todayCost).font(.caption).foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.trend14Days).font(.caption).foregroundColor(.secondary)
                    Chart {
                        ForEach(data.dailyCosts) { dc in
                            BarMark(x: .value("D", dc.date), y: .value("C", dc.amount))
                                .foregroundStyle(LinearGradient(
                                    colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                                .annotation(position: .top, alignment: .center, spacing: 0) {
                                    Text(entry.displayAmount(dc.amount))
                                        .font(.system(size: 7))
                                        .foregroundColor(.secondary)
                                }
                        }
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits)).font(.system(size: 8))
                    }}
                    .chartYAxis { AxisMarks(position: .trailing) { _ in AxisValueLabel().font(.system(size: 8)) }}
                    .frame(height: 80)
                    .padding(.bottom, 4)
                }
                if !data.modelCosts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.modelDistribution).font(.caption).foregroundColor(.secondary)
                        ForEach(data.modelCosts) { mc in
                            let pct = min(max(mc.percentage, 0), 100)
                            VStack(spacing: 3) {
                                HStack {
                                    Text(mc.displayName).font(.caption)
                                    Spacer()
                                    Text(entry.displayAmount(mc.amount)).font(.caption.monospacedDigit()).foregroundColor(.accentColor)
                                }
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.5)).frame(width: geo.size.width * pct / 100)
                                }.frame(height: 6)
                            }
                        }
                    }
                }
                HStack {
                    Text("\(L10n.balance) \(entry.displayAmount(data.totalBalance))").font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                    Spacer()
                    Text("\(L10n.updated) \(formatTime(data.lastUpdated))").font(.caption2).foregroundColor(.secondary)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "key.fill").font(.title).foregroundColor(.accentColor)
                Text(entry.error ?? L10n.noAPIKey).font(.caption).foregroundColor(.secondary)
                Text(L10n.openAppToConfig).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private func formatTime(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date) }
}
