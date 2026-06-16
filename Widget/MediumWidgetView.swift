import SwiftUI
import WidgetKit
import Charts

struct MediumWidgetView: View {
    let entry: CostEntry

    var body: some View {
        if let data = entry.costData {
            HStack(spacing: 12) {
                // 左侧：金额
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text("DeepSeek")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.monthlyCost))
                            .font(.title2.monospacedDigit())
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text(L10n.monthlyCost)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayAmount(data.todayCost))
                            .font(.headline.monospacedDigit())
                        Text(L10n.todayCost)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text("\(L10n.balance)  \(entry.displayAmount(data.totalBalance))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                // 右侧：图表 + 模型
                VStack(spacing: 8) {
                    // 14天趋势柱状图
                    if !data.dailyCosts.isEmpty {
                        Chart {
                            ForEach(data.dailyCosts) { dc in
                                BarMark(
                                    x: .value("日期", dc.date),
                                    y: .value("费用", dc.amount)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.6))
                                .annotation(position: .top, alignment: .center, spacing: 0) {
                                    Text(entry.displayAmount(dc.amount))
                                        .font(.system(size: 6))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                                    .font(.system(size: 7))
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 60)
                    }

                    if !data.modelCosts.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(data.modelCosts.prefix(3)) { mc in
                                VStack(spacing: 2) {
                                    Text(mc.displayName)
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                    Text("\(Int(mc.percentage))%")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            errorView
        }
    }

    private var errorView: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(entry.error ?? L10n.noAPIKey)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}
