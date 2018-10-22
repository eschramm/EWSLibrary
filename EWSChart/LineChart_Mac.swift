//
//  LineChart_Mac.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 10/15/18.
//  Copyright © 2018 eware. All rights reserved.
//

import AppKit

class LineChartView : NSView, AxisDrawable {
    func drawAxis(from: CGPoint, to: CGPoint, width: CGFloat, colorAlpha: CGFloat) {
        //complete below
    }
    
    func drawAxisStepLabel(label: String, atPoint: CGPoint) {
        //complete below
    }
    
    
    //recall
    // ^
    // |
    // |
    // |
    //0,0 -------->
    
    struct CocoaView: CocoaViewable {
        var frame: Frameable
        let isAppKit = true
    }
    
    var dataSource: ChartDataSource!
    
    var cocoaView: CocoaView!
    var chartCalc: ChartCalculations!
    
    var textFields = [NSTextField]()
    
    let labelsFont = NSFont.systemFont(ofSize: 14)
    
    init(frame: NSRect, dataSource: ChartDataSource, parameters: ChartParameters?) {
        super.init(frame: frame)
        self.dataSource = dataSource
        self.chartCalc = ChartCalculations(dataSource: dataSource, cocoaView: CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width))), chartType: .bar, parameters: parameters)
    }
    
    required init?(coder: NSCoder) {
        //fatalError("init(coder:) has not been implemented")
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        if dirtyRect == NSRect.zero {
            return
        }
        cocoaView = CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width)))
        chartCalc.cocoaView = cocoaView
        
        //Drawing Code
        
        drawBackground(with: NSColor.clear)
        //chartCalc.drawAxes(drawer: self)
        drawData()
        
    }
    
    func drawBackground(with color: NSColor) {
        color.setFill()
        NSRect(origin: frame.origin, size: frame.size).fill()
    }
    
    /*
    func drawAxis(from: CGPoint, to: CGPoint, width: CGFloat, colorAlpha: CGFloat) {
        let axisPath = NSBezierPath()
        let chartAxisColor = NSColor.red.withAlphaComponent(colorAlpha)
        axisPath.move(to: from)
        axisPath.line(to: to)
        axisPath.lineWidth = width
        chartAxisColor.setStroke()
        axisPath.stroke()
    }
    
    func drawAxisStepLabel(label: String, atPoint: CGPoint) {
        
        let context = NSGraphicsContext.current?.cgContext
        context?.setTextDrawingMode(.fill)
        context?.setFillColor(NSColor.red.cgColor)
        
        let textFont = NSFont.systemFont(ofSize: 10)
        let sizeOfFont = label.size(withAttributes: [NSAttributedString.Key.font : textFont])
        label.draw(in: CGRect(x: atPoint.x, y: atPoint.y, width: sizeOfFont.width, height: sizeOfFont.height), withAttributes: [NSAttributedString.Key.font : textFont])
        
    }
    
    func drawAxes() {
        
        //let chartAxisStepWidth: CGFloat = chartAxisWidth / 2
        let chartAxisColor = NSColor.red
        let yAxisPath = NSBezierPath()
        let axisWidth = chartCalc.parameters.axisWidth
        let xPaddingToAxis = chartCalc.parameters.xPaddingToAxis
        let yPaddingToAxis = chartCalc.parameters.yPaddingToAxis
        yAxisPath.lineWidth = axisWidth
        yAxisPath.move(to: CGPoint(x: xPaddingToAxis + axisWidth / 2, y: yPaddingToAxis))
        yAxisPath.line(to: CGPoint(x: xPaddingToAxis + axisWidth / 2, y: frame.size.height - yPaddingToAxis))
        
        let xAxisPath = NSBezierPath()
        xAxisPath.lineWidth = axisWidth
        let xAxisYval = chartCalc.yValueCalculated(for: 0)  //exact center
        xAxisPath.move(to: CGPoint(x: xPaddingToAxis, y: xAxisYval))
        xAxisPath.line(to: CGPoint(x: frame.size.width - xPaddingToAxis, y: xAxisYval))
        
        chartAxisColor.setStroke()
        yAxisPath.stroke()
        xAxisPath.stroke()
        
    }
    */
    
    func drawData() {
        
        if frame == NSRect.zero {
            return
        }
        
        self.chartCalc.cocoaView = CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width)))
        //preCalcLabelSizes()
        
        var lastUpperRect = NSRect.zero
        var lastLowerRect = NSRect.zero
        let yZeroVal = chartCalc.yValueCalculated(for: 0)
        let dataLine = NSBezierPath()
        let lineColor = NSColor.green
        
        for index in 0..<chartCalc.dataCount {
            
            let calculatedPoint = chartCalc.linePoint(index: index)
            let dataPoint = CGPoint(x: calculatedPoint.x, y: calculatedPoint.y)
            
            if index == 0 {
                dataLine.move(to: dataPoint)
            } else {
                dataLine.line(to: dataPoint)
            }
            
            dataLine.lineWidth = 4
            lineColor.setStroke()
            dataLine.stroke()
            
            /*
            if let labelText = dataSource.label(for: index) {
                
                if chartCalc.parameters.drawXaxisLabelsAtAngle {
                    
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    var label: NSTextField
                    if textFields.count >= (index + 1) {
                        label = textFields[index]
                    } else {
                        label = NSTextField()
                        label.isBordered = false
                        label.backgroundColor = NSColor.clear
                        label.rotate(byDegrees: -45)
                        addSubview(label)
                        textFields.append(label)
                    }
                    label.frame = NSRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal - (sizeOfFont.width * 0.6 * CGFloat(sqrt(2))), width: sizeOfFont.width + 10, height: sizeOfFont.height)
                    label.stringValue = labelText
                } else {
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    let labelRect = NSRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal - sizeOfFont.height - 2, width: sizeOfFont.width, height: sizeOfFont.height)
                    if !labelRect.intersects(lastUpperRect) {
                        labelText.draw(in: labelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                        lastUpperRect = labelRect
                    } else {
                        let offsetLabelRect = NSRect(x: labelRect.origin.x, y: labelRect.origin.y - sizeOfFont.height - 2, width: labelRect.width, height: labelRect.height)
                        if !offsetLabelRect.intersects(lastLowerRect) {
                            labelText.draw(in: offsetLabelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                            lastLowerRect = offsetLabelRect
                        }
                    }
                }
            }
             */
        }
    }
    
    func preCalcLabelSizes() {
        
        let yZeroVal = chartCalc.yValueCalculated(for: 0)
        var totalLabelsLength: CGFloat = 0
        var maxLabelHeight: CGFloat = 0
        
        for index in 0...(chartCalc.dataCount - 1) {
            
            let barOrigin = chartCalc.barOrigin(index: index)
            let barSize = chartCalc.barSize(index: index)
            let barRect = NSRect(x: barOrigin.x, y: barOrigin.y, width: barSize.width, height: barSize.height)
            
            let barRectCenterX = barRect.origin.x + (barSize.width / 2)
            
            if let labelText = dataSource.label(for: index) {
                
                if chartCalc.parameters.drawXaxisLabelsAtAngle {
                    
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    var label: NSTextField
                    if textFields.count >= (index + 1) {
                        label = textFields[index]
                    } else {
                        label = NSTextField()
                        label.isBordered = false
                        label.backgroundColor = NSColor.clear
                        label.rotate(byDegrees: -45)
                        addSubview(label)
                        textFields.append(label)
                    }
                    label.frame = NSRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal - (sizeOfFont.width * 0.6 * CGFloat(sqrt(2))), width: sizeOfFont.width + 10, height: sizeOfFont.height)
                    label.stringValue = labelText
                } else {
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    totalLabelsLength += (sizeOfFont.width + 10)
                    
                    if sizeOfFont.height + 10 > maxLabelHeight {
                        maxLabelHeight = sizeOfFont.height + 10
                    }
                }
            }
        }
        
        if chartCalc.parameters.drawXaxisLabelsAtAngle {
        } else {
            if maxLabelHeight > chartCalc.parameters.yAxis.yPadding {
                printView("fart")
            }
        }
        
    }
    
}



class TestLineChartViewController : NSViewController {
    
    struct Element {
        let xVal: Double
        let yVal: Double
        let label: String
    }
    
    var elements = [Element]()
    var lineChart: LineChartView!
    
    override func viewDidLoad() {
        
        elements.append(Element(xVal: 1, yVal: 2, label: "4/1/2016"))
        elements.append(Element(xVal: 2, yVal: 2.7, label: "5/1/2016"))
        elements.append(Element(xVal: 3, yVal: 3.8, label: "6/1/2016"))
        elements.append(Element(xVal: 4, yVal: 1.75, label: "7/1/2016"))
        elements.append(Element(xVal: 5, yVal: 4.9, label: "8/1/2016"))
        elements.append(Element(xVal: 6, yVal: 6.9, label: "9/1/2016"))
        
        var parameters = ChartParameters()
        //parameters.yAxisMin = -4
        parameters.drawXaxisLabelsAtAngle = true
        parameters.yAxis.yPadding = 100
        parameters.xAxis.yPadding = 100
        
        lineChart = LineChartView(frame: NSRect.zero, dataSource: self, parameters: parameters)
        lineChart.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [NSLayoutConstraint]()
        view.addSubview(lineChart)
        
        constraints.append(lineChart.widthAnchor.constraint(equalTo: view.widthAnchor))
        constraints.append(lineChart.heightAnchor.constraint(equalTo: view.heightAnchor))
        constraints.append(lineChart.topAnchor.constraint(equalTo: view.topAnchor))
        constraints.append(lineChart.leadingAnchor.constraint(equalTo: view.leadingAnchor))
        NSLayoutConstraint.activate(constraints)
        
        lineChart.draw(lineChart.frame)
        //weak var weakself = self
        
        //add this to force redraw on window resize
        /*NotificationCenter.default.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: nil, queue: OperationQueue.main) { (notification: Notification) in
         
         //let strongSelf = weakself
         
         self.barChart.draw(self.barChart.frame)
         }*/
        
    }
    
}

extension TestLineChartViewController : ChartDataSource {
    
    func dataCount() -> Int {
        return elements.count
    }
    
    func xValue(for index: Int) -> Double? {
        return elements[index].xVal
    }
    
    func yValue(for index: Int) -> Double {
        return elements[index].yVal
    }
    
    func label(for index: Int) -> String? {
        return elements[index].label
    }
}
