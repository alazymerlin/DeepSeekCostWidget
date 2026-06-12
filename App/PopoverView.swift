import SwiftUI

struct PopoverView: View {
    @ObservedObject private var dm = DataManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("DeepSeek", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()

                if dm.isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Content
            if let data = dm.costData {
                VStack(spacing: 12) {
                    // 消耗概览
                    HStack(spacing: 20) {
                        costBlock(title: "本月消耗", amount: dm.displayAmount(data.monthlyCost))
                        costBlock(title: "今日消耗", amount: dm.displayAmount(data.todayCost))
                    }

                    // 余额
                    HStack {
                        Text("💰 余额")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dm.displayAmount(data.totalBalance))
                            .font(.subheadline.monospacedDigit())
                    }

                    // 模型分布
                    if !data.modelCosts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模型消耗")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(data.modelCosts) { mc in
                                modelRow(mc, dm: dm)
                            }
                        }
                    }

                    // 更新时间
                    Text("更新于 \(formatTime(data.lastUpdated))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
            } else if let error = dm.lastError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(20)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button(action: { dm.refresh() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button(action: { openSettings() }) {
                    Label("设置", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    private func costBlock(title: String, amount: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(amount)
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
        }
    }

    private func modelRow(_ mc: ModelCost, dm: DataManager) -> some View {
        HStack(spacing: 6) {
            Text(mc.displayName)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: geo.size.width * mc.percentage / 100)
            }
            .frame(height: 8)
            Text(dm.displayAmount(mc.amount))
                .font(.caption.monospacedDigit())
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
