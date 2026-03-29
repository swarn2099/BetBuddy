import SwiftUI
import Charts

struct BalanceGraphView: View {
    let history: [BalanceHistoryEntry]
    @Binding var selectedRange: TimeRange

    enum TimeRange: String, CaseIterable {
        case week = "7d"
        case month = "30d"
        case all = "All"
    }

    private var filteredHistory: [BalanceHistoryEntry] {
        let now = Date()
        switch selectedRange {
        case .week:
            return history.filter { $0.createdAt >= now.addingTimeInterval(-7 * 86400) }
        case .month:
            return history.filter { $0.createdAt >= now.addingTimeInterval(-30 * 86400) }
        case .all:
            return history
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Time range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if filteredHistory.isEmpty {
                Text("No history yet")
                    .font(.cardMeta)
                    .foregroundStyle(Color.textSecondary)
                    .frame(height: 150)
            } else {
                Chart {
                    // $1000 reference line
                    RuleMark(y: .value("Start", 1000))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.textMuted)

                    ForEach(filteredHistory) { entry in
                        LineMark(
                            x: .value("Time", entry.createdAt),
                            y: .value("Balance", entry.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Time", entry.createdAt),
                            y: .value("Balance", entry.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentPrimary.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("$\(v)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .glassCard()
    }
}
