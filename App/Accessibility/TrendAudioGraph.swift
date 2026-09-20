import Accessibility
import ReportCore
import SwiftUI

/// Exposes a metric's trend to VoiceOver as an Audio Graph: the listener can
/// play the line as rising and falling pitch and step through its points, the
/// same way Apple's own charts work in Stocks and Health.
struct TrendChartDescriptor: AXChartDescriptorRepresentable {
    let metric: Metric

    func makeChartDescriptor() -> AXChartDescriptor {
        let values = metric.trend
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Period",
            range: 1 ... Double(max(values.count, 2)),
            gridlinePositions: []
        ) { "Period \(Int($0))" }
        let yAxis = AXNumericDataAxisDescriptor(
            title: metric.label.isEmpty ? "Value" : metric.label,
            range: (low == high ? low - 1 : low) ... (low == high ? high + 1 : high),
            gridlinePositions: []
        ) { NumberParsing.format($0) }
        let series = AXDataSeriesDescriptor(
            name: metric.label,
            isContinuous: true,
            dataPoints: values.enumerated().map { AXDataPoint(x: Double($0.offset + 1), y: $0.element) }
        )
        return AXChartDescriptor(
            title: "\(metric.label) trend",
            summary: Self.summary(of: values),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        descriptor.series = makeChartDescriptor().series
    }

    static func summary(of values: [Double]) -> String {
        guard let first = values.first, let last = values.last, values.count >= 2 else { return "No trend data." }
        let direction = last > first ? "rose" : last < first ? "fell" : "stayed level"
        return "Over \(values.count) periods the value \(direction) from \(NumberParsing.format(first)) to \(NumberParsing.format(last))."
    }
}

extension View {
    /// Adds an Audio Graph when the metric has a trend to play.
    @ViewBuilder
    func trendAudioGraph(for metric: Metric) -> some View {
        if metric.trend.count >= 2 {
            accessibilityChartDescriptor(TrendChartDescriptor(metric: metric))
        } else {
            self
        }
    }
}
