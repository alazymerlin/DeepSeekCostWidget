import WidgetKit
import SwiftUI

@main
struct DeepSeekCostWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeepSeekCostWidget()
    }
}

struct DeepSeekCostWidget: Widget {
    let kind = "com.deepseekcostwidget.app.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CostProvider()
        ) { entry in
            WidgetEntryView(entry: entry)
                .containerBackground(.ultraThinMaterial, for: .widget)
        }
        .configurationDisplayName("DeepSeek Cost")
        .description("Monitor DeepSeek API usage and balance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
