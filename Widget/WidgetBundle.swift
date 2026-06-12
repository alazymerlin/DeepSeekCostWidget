import WidgetKit
import SwiftUI

@main
struct DeepSeekCostWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeepSeekCostWidget()
    }
}

struct DeepSeekCostWidget: Widget {
    let kind = "com.deepseekcostwidget.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CostProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("DeepSeek 费用")
        .description("查看 DeepSeek API 消耗情况")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
