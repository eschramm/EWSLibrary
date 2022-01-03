//
//  EWSLongitudinalReport.swift
//
//  Created by Eric Schramm on 1/2/22.
//

#if os(macOS)
import AppKit
import SwiftUI
import Charts


public protocol LongitudinalReportDataSource {
    func barChartValues(for interval: DateInterval) -> [Double]?
    func overrideMaxIntervals(for bucketType: LongitudinalReport.BucketType) -> Int?
    var dataSetLabel: String? { get }
    var valueStackLabels: [String] { get }
    var dataSetColors: [NSColor] { get }
}

public class LongitudinalReport: NSObject {
    public enum BucketType: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        
        func current(calendar: Calendar) -> DateInterval {
            switch self {
            case .week:
                let nextSunday = calendar.nextDate(after: Date(), matching: DateComponents(weekday: 1), matchingPolicy: .nextTime)!
                let dateFrom = calendar.date(byAdding: .day, value: -7, to: nextSunday)!.truncateToMidnight(calendar: calendar)!
                var diff = DateComponents()
                diff.day = 6
                let dateTo = calendar.date(byAdding: diff, to: dateFrom)!.truncateToMidnight(calendar: calendar)!.addingTimeInterval(60 * 60 * 24 - 1)
                return DateInterval(start: dateFrom, end: dateTo)
            case .month:
                let components = calendar.dateComponents(Set(arrayLiteral: .year, .month), from: Date())
                let dateFrom = calendar.date(from: components)!.truncateToMidnight(calendar: calendar)!
                var diff = DateComponents()
                diff.month = 1
                diff.day = -1
                let dateTo = calendar.date(byAdding: diff, to: dateFrom)!.truncateToMidnight(calendar: calendar)!.addingTimeInterval(60 * 60 * 24 - 1)
                return DateInterval(start: dateFrom, end: dateTo)
            case .quarter:
                let components = calendar.dateComponents(Set(arrayLiteral: .year, .month), from: Date())
                let firstDateOfMonth = calendar.date(from: components)!
                var diff = DateComponents()
                diff.month = -((components.month! - 1) % 3)
                let dateFrom = calendar.date(byAdding: diff, to: firstDateOfMonth)!
                diff.month = 3
                diff.day = -1
                let dateTo = calendar.date(byAdding: diff, to: dateFrom)!.addingTimeInterval(60 * 60 * 24 - 1)
                return DateInterval(start: dateFrom, end: dateTo)
            case .year:
                let components = calendar.dateComponents(Set(arrayLiteral: .year), from: Date())
                let dateFrom = calendar.date(from: components)!
                var diff = DateComponents()
                diff.month = 12
                diff.day = -1
                let dateTo = calendar.date(byAdding: diff, to: dateFrom)!.addingTimeInterval(60 * 60 * 24 - 1)
                return DateInterval(start: dateFrom, end: dateTo)
            }
        }
        
        func previousInterval(from interval: DateInterval, calendar: Calendar) -> DateInterval {
            //assumes a valid interval
            let dateTo = calendar.date(byAdding: .day, value: -1, to: interval.start)!.truncateToMidnight(calendar: calendar)!.addingTimeInterval(60 * 60 * 24 - 1)
            let dateFrom: Date
            switch self {
            case .week:
                dateFrom = calendar.date(byAdding: .day, value: -7, to: interval.start)!.truncateToMidnight(calendar: calendar)!
            case .month:
                dateFrom = calendar.date(byAdding: .month, value: -1, to: interval.start)!.truncateToMidnight(calendar: calendar)!
            case .quarter:
                dateFrom = calendar.date(byAdding: .month, value: -3, to: interval.start)!.truncateToMidnight(calendar: calendar)!
            case .year:
                dateFrom = calendar.date(byAdding: .year, value: -1, to: interval.start)!.truncateToMidnight(calendar: calendar)!
            }
            return DateInterval(start: dateFrom, end: dateTo)
        }
        
        func nextInterval(from interval: DateInterval, calendar: Calendar) -> DateInterval {
            //assumes a valid interval
            let dateFrom = interval.end.addingTimeInterval(1)
            let dateTo: Date
            switch self {
            case .week:
                dateTo = calendar.date(byAdding: .day, value: 7, to: dateFrom)!.truncateToMidnight(calendar: calendar)!
            case .month:
                dateTo = calendar.date(byAdding: .month, value: 1, to: dateFrom)!.truncateToMidnight(calendar: calendar)!
            case .quarter:
                dateTo = calendar.date(byAdding: .month, value: 3, to: dateFrom)!.truncateToMidnight(calendar: calendar)!
            case .year:
                dateTo = calendar.date(byAdding: .year, value: 1, to: dateFrom)!.truncateToMidnight(calendar: calendar)!
            }
            return DateInterval(start: dateFrom, end: dateTo.addingTimeInterval(-1))
        }
        
        func advanceIntervals(from interval: DateInterval, count: Int) -> DateInterval {
            var interval = interval
            for _ in 1...count {
                interval = nextInterval(from: interval, calendar: Calendar.current)
            }
            return interval
        }
        
        func advanceIntervalsToContain(date: Date, from interval: DateInterval, calendar: Calendar) -> DateInterval {
            if date < interval.end {
                return interval
            }
            var currentInterval = interval
            while !currentInterval.contains(date) {
                currentInterval = nextInterval(from: currentInterval, calendar: calendar)
            }
            return currentInterval
        }
        
        func intervalCount(for interval: DateInterval, calendar: Calendar) -> Int {
            switch self {
            case .month:
                return calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 0
            case .year:
                return calendar.dateComponents([.year], from: interval.start, to: interval.end).year ?? 0
            case .quarter:
                return (calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 0) / 3
            case .week:
                return (calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0) / 7
            }
        }
        
        var defaultMaxIntervals: Int {
            switch self {
            case .week:
                return 52
            case .month:
                return 12
            case .quarter:
                return 12
            case .year:
                return 10
            }
        }
    }
    
    let dataSource: LongitudinalReportDataSource
    
    let barChartView: BarChartView
    let bucketComboBox: NSComboBox
    var bucketType: BucketType?
    
    var newestInterval: DateInterval?
    var oldestInterval: DateInterval?
    
    weak var presentingViewController: NSViewController?
    
    public init(dataSource: LongitudinalReportDataSource, barChartView: BarChartView, bucketComboBox: NSComboBox, presentingVC: NSViewController) {
        self.dataSource = dataSource
        self.barChartView = barChartView
        self.bucketComboBox = bucketComboBox
        self.presentingViewController = presentingVC
        super.init()
        
        bucketComboBox.removeAllItems()
        bucketComboBox.addItems(withObjectValues: BucketType.allCases.map({ $0.rawValue }))
        let defaultIndex = 0
        bucketComboBox.selectItem(at: defaultIndex)
        bucketType = BucketType.allCases[defaultIndex]
        bucketComboBox.delegate = self
        addButtons()
    }
    
    func addButtons() {
        let backButton = NSButton(image: NSImage(named: NSImage.goBackTemplateName)!, target: self, action: #selector(goBackward(_:)))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        barChartView.superview?.addSubview(backButton)
        let forwardButton = NSButton(image: NSImage(named: NSImage.goForwardTemplateName)!, target: self, action: #selector(goForward(_:)))
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        barChartView.superview?.addSubview(forwardButton)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: barChartView.leadingAnchor),
            backButton.bottomAnchor.constraint(equalTo: barChartView.bottomAnchor),
            forwardButton.trailingAnchor.constraint(equalTo: barChartView.trailingAnchor),
            forwardButton.bottomAnchor.constraint(equalTo: barChartView.bottomAnchor)
        ])
    }
    
    @objc func goBackward(_ sender: AnyObject) {
        if let event = NSApp.currentEvent, event.isRightClick, let oldestInterval = oldestInterval, let newestInterval = newestInterval {
            let sheetVC = NSViewController(nibName: nil, bundle: nil)
            sheetVC.title = "Adjust Start Date"
            let pickerView = NSHostingView(rootView: LongitudinalEndDatePickerView(title: "Start Date", date: oldestInterval.start) { date in
                self.presentingViewController?.dismiss(sheetVC)
                self.drawReport(intervalCount: self.bucketType?.intervalCount(for: DateInterval(start: date, end: newestInterval.end), calendar: Calendar.current))
            })
            pickerView.frame = CGRect(origin: .zero, size: CGSize(width: 250, height: 150))
            sheetVC.view = pickerView
            presentingViewController?.presentAsModalWindow(sheetVC)
        } else {
            guard let bucketType = bucketType, let oldestInterval = oldestInterval else {
                return
            }
            newestInterval = bucketType.previousInterval(from: oldestInterval, calendar: Calendar.current)
            self.oldestInterval = nil
            drawReport()
        }
    }
    
    @objc func goForward(_ sender: AnyObject) {
        if let event = NSApp.currentEvent, event.isRightClick, let oldestInterval = oldestInterval, let newestInterval = newestInterval, let bucketType = bucketType {
            let sheetVC = NSViewController(nibName: nil, bundle: nil)
            sheetVC.title = "Adjust End Date"
            let pickerView = NSHostingView(rootView: LongitudinalEndDatePickerView(title: "End Date", date: newestInterval.end) { date in
                self.presentingViewController?.dismiss(sheetVC)
                self.newestInterval = bucketType.advanceIntervalsToContain(date: date, from: newestInterval, calendar: .current)
                self.drawReport(intervalCount: bucketType.intervalCount(for: DateInterval(start: oldestInterval.start, end: date), calendar: .current))
            })
            pickerView.frame = CGRect(origin: .zero, size: CGSize(width: 250, height: 150))
            sheetVC.view = pickerView
            presentingViewController?.presentAsModalWindow(sheetVC)
        } else {
            guard let bucketType = bucketType, let newestInterval = newestInterval else {
                return
            }
            self.newestInterval = bucketType.advanceIntervals(from: newestInterval, count: (dataSource.overrideMaxIntervals(for: bucketType) ?? bucketType.defaultMaxIntervals))
            oldestInterval = nil
            drawReport()
        }
    }
    
    public func drawReport(intervalCount: Int? = nil) {
        let bucketIdx = bucketComboBox.indexOfSelectedItem
        guard bucketIdx >= 0 else { return }
        guard let bucketStr = bucketComboBox.itemObjectValue(at: bucketIdx) as? String else { return }
        guard let bucketType = BucketType(rawValue: bucketStr) else { return }
        self.bucketType = bucketType
        if newestInterval == nil {
            newestInterval = bucketType.current(calendar: Calendar.current)
        }
        
        var currentInterval = newestInterval!
        var intervalOffset: Double = 0
        
        var entries = [BarChartDataEntry]()
        let maxIntervals = intervalCount ?? dataSource.overrideMaxIntervals(for: bucketType) ?? bucketType.defaultMaxIntervals
        
        var complete = false
        
        repeat {
            guard let values = dataSource.barChartValues(for: currentInterval) else {
                complete = true
                continue
            }
            if newestInterval == nil {
                newestInterval = currentInterval
            }
            entries.append(BarChartDataEntry(x: intervalOffset, yValues: values))
            oldestInterval = currentInterval
            if entries.count >= maxIntervals {
                complete = true
            } else {
                currentInterval = bucketType.previousInterval(from: currentInterval, calendar: Calendar.current)
                intervalOffset -= 1
            }
        } while !complete
        
        let data = BarChartData()
        let dataSet = BarChartDataSet(entries: entries, label: dataSource.dataSetLabel)
        dataSet.colors = dataSource.dataSetColors
        dataSet.stackLabels = dataSource.valueStackLabels
        data.addDataSet(dataSet)
        
        barChartView.data = data
        barChartView.xAxis.valueFormatter = IntervalFormatter(bucketType: bucketType, currentInterval: newestInterval!)
        
        barChartView.animate(xAxisDuration: 1.0)
    }
}

extension LongitudinalReport: NSComboBoxDelegate {
    public func comboBoxSelectionDidChange(_ notification: Notification) {
        newestInterval = nil
        drawReport()
    }
}

// https://www.jessesquires.com/blog/2019/08/15/implementing-right-click-for-nsbutton/
extension NSEvent {
    var isRightClick: Bool {
        let rightClick = (self.type == .rightMouseDown)
        let controlClick = self.modifierFlags.contains(.control)
        return rightClick || controlClick
    }
}

public struct LongitudinalEndDatePickerView: View {
    
    let title: String
    @State var date: Date
    let completion: (Date) -> ()
    
    public var body: some View {
        VStack {
            DatePicker(selection: $date, displayedComponents: .date) {
                Text(title)
            }
            Button("Update") {
                completion(date)
            }
        }
        .padding(.all, 20)
    }
}

struct LongitudinalEndDatePickerView_Preview: PreviewProvider {
    
    static var previews: some View {
        LongitudinalEndDatePickerView(title: "Start Date", date: Date(), completion: { _ in })
    }
}

class IntervalFormatter: IAxisValueFormatter {
    
    let bucketType: LongitudinalReport.BucketType
    let currentInterval: DateInterval
    
    init(bucketType: LongitudinalReport.BucketType, currentInterval: DateInterval) {
        self.bucketType = bucketType
        self.currentInterval = currentInterval
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if value == 0 {
            return DateFormatter.shortDateFormatter.string(from: currentInterval.start)
        }
        let date: Date
        switch bucketType {
        case .week:
            date = Calendar.current.date(byAdding: .day, value: Int(value * 7), to: currentInterval.start)!
        case .month:
            date = Calendar.current.date(byAdding: .month, value: Int(value), to: currentInterval.start)!
        case .quarter:
            date = Calendar.current.date(byAdding: .month, value: Int(value * 3), to: currentInterval.start)!
        case .year:
            date = Calendar.current.date(byAdding: .year, value: Int(value), to: currentInterval.start)!
        }
        return DateFormatter.shortDateFormatter.string(from: date)
    }
}
#endif
