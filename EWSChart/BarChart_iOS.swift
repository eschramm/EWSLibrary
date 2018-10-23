//
//  Chart_iOS.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 10/12/18.
//  Copyright © 2018 eware. All rights reserved.
//

import UIKit

public class BarChartView: UIView, AxisDrawable {
    
    //recall
    //0,0 -------->
    // |
    // |
    // |
    // v
    
    struct CocoaView: CocoaViewable {
        var frame: Frameable
        let isAppKit = false
    }
    
    let dataSource: ChartDataSource
    let chartIdentifier: String
    
    var cocoaView: CocoaView!
    var chartCalc: ChartCalculations!
    var labels = [UILabel]()
    
    let labelsFont = UIFont.systemFont(ofSize: 14)
    
    public init(frame: CGRect, dataSource: ChartDataSource, parameters: ChartParameters?, identifier: String) {
        self.dataSource  = dataSource
        self.chartIdentifier = identifier
        super.init(frame: frame)
        self.chartCalc = ChartCalculations(dataSource: dataSource, cocoaView: CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width))), chartType: .bar, parameters: parameters, identifier: identifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.setNeedsDisplay()
    }
    
    public override func draw(_ dirtyRect: CGRect) {
        
        cocoaView = CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width)))
        chartCalc.cocoaView = cocoaView
        
        //Drawing Code
        
        drawBackground(with: UIColor.white)
        chartCalc.drawAxes(drawer: self)
        drawData()
        
    }
    
    func drawBackground(with color: UIColor) {
        color.setFill()
        UIRectFill(CGRect(origin: frame.origin, size: frame.size))
    }
    
    func drawAxis(from: CGPoint, to: CGPoint, width: CGFloat, colorAlpha: CGFloat) {
        let axisPath = UIBezierPath()
        let chartAxisColor = UIColor.red.withAlphaComponent(colorAlpha)
        axisPath.move(to: from)
        axisPath.addLine(to: to)
        axisPath.lineWidth = width
        chartAxisColor.setStroke()
        axisPath.stroke()
    }
    
    func drawAxisStepLabel(label: String, atPoint: CGPoint) {
        let context = UIGraphicsGetCurrentContext()
        context?.setTextDrawingMode(.fill)
        context?.setFillColor(UIColor.red.cgColor)
        
        let textFont = UIFont.systemFont(ofSize: 10)
        let sizeOfFont = label.size(withAttributes: [NSAttributedString.Key.font : textFont])
        label.draw(in: CGRect(x: atPoint.x, y: atPoint.y, width: sizeOfFont.width, height: sizeOfFont.height), withAttributes: [NSAttributedString.Key.font : textFont])
    }
    
    func drawData() {
        
        if frame == CGRect.zero {
            return
        }
        
        self.chartCalc.cocoaView = CocoaView(frame: Frame(origin: Origin(x: frame.origin.x, y: frame.origin.y) , size: Size(height: frame.size.height, width: frame.size.width)))
        
        var lastUpperRect = CGRect.zero
        var lastLowerRect = CGRect.zero
        let yZeroVal = chartCalc.yValueCalculated(for: 0)
        
        for index in 0...(chartCalc.dataCount - 1) {
            
            let barColor = UIColor.green
            let barOrigin = chartCalc.barOrigin(index: index)
            let barSize = chartCalc.barSize(index: index)
            let barRect = CGRect(x: barOrigin.x, y: barOrigin.y, width: barSize.width, height: barSize.height)
            
            let barRectCenterX = barRect.origin.x + (barSize.width / 2)
            
            barColor.setFill()
            UIRectFill(barRect)
            
            if let labelText = dataSource.label(identifier: chartIdentifier, index: index) {
                
                if chartCalc.parameters.drawXaxisLabelsAtAngle {
                    
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    var label: UILabel
                    if labels.count >= (index + 1) {
                        label = labels[index]
                    } else {
                        label = UILabel()
                        label.backgroundColor = UIColor.clear
                        //label.transform.rotated(by: -2)
                        label.transform = CGAffineTransform(rotationAngle: -90.0 * 3.1415 / 180.0)
                        addSubview(label)
                        labels.append(label)
                    }
                    label.frame = CGRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal + (sizeOfFont.width * 0.6 * CGFloat(sqrt(2))), width: sizeOfFont.width + 10, height: sizeOfFont.height)
                    label.text = labelText
                } else {
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    let labelRect = CGRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal + sizeOfFont.height + 2, width: sizeOfFont.width, height: sizeOfFont.height)
                    if !labelRect.intersects(lastUpperRect) {
                        labelText.draw(in: labelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                        lastUpperRect = labelRect
                    } else {
                        let offsetLabelRect = CGRect(x: labelRect.origin.x, y: labelRect.origin.y + sizeOfFont.height + 2, width: labelRect.width, height: labelRect.height)
                        if !offsetLabelRect.intersects(lastLowerRect) {
                            labelText.draw(in: offsetLabelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                            lastLowerRect = offsetLabelRect
                        }
                    }
                }
            }
        }
        
    }
    
    func labelsPreCalc() {
        
        //var totalWidth: CGFloat = 0
        
        var lastUpperRect = CGRect.zero
        var lastLowerRect = CGRect.zero
        let yZeroVal = chartCalc.yValueCalculated(for: 0)
        
        for index in 0...(chartCalc.dataCount - 1) {
            let barOrigin = chartCalc.barOrigin(index: index)
            let barSize = chartCalc.barSize(index: index)
            let barRect = CGRect(x: barOrigin.x, y: barOrigin.y, width: barSize.width, height: barSize.height)
            
            let barRectCenterX = barRect.origin.x + (barSize.width / 2)
            
            if let labelText = dataSource.label(identifier: chartIdentifier, index: index) {
                
                if chartCalc.parameters.drawXaxisLabelsAtAngle {
                    
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    var label: UILabel
                    if labels.count >= (index + 1) {
                        label = labels[index]
                    } else {
                        label = UILabel()
                        label.backgroundColor = UIColor.clear
                        //label.transform.rotated(by: -2)
                        label.transform = CGAffineTransform(rotationAngle: -90.0 * 3.1415 / 180.0)
                        addSubview(label)
                        labels.append(label)
                    }
                    label.frame = CGRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal + (sizeOfFont.width * 0.6 * CGFloat(sqrt(2))), width: sizeOfFont.width + 10, height: sizeOfFont.height)
                    label.text = labelText
                } else {
                    let sizeOfFont = labelText.size(withAttributes: [NSAttributedString.Key.font : labelsFont])
                    
                    let labelRect = CGRect(x: barRectCenterX - (sizeOfFont.width / 2), y: yZeroVal + sizeOfFont.height + 2, width: sizeOfFont.width, height: sizeOfFont.height)
                    if !labelRect.intersects(lastUpperRect) {
                        labelText.draw(in: labelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                        lastUpperRect = labelRect
                    } else {
                        let offsetLabelRect = CGRect(x: labelRect.origin.x, y: labelRect.origin.y + sizeOfFont.height + 2, width: labelRect.width, height: labelRect.height)
                        if !offsetLabelRect.intersects(lastLowerRect) {
                            labelText.draw(in: offsetLabelRect, withAttributes: [NSAttributedString.Key.font : labelsFont])
                            lastLowerRect = offsetLabelRect
                        }
                    }
                }
            }
        }
    }
}

class TestViewController : UIViewController {
    
    struct Element {
        let xVal: Double
        let yVal: Double
        let label: String
    }
    
    var elements = [Element]()
    var barChart: BarChartView!
    
    override func viewDidLoad() {
        
        elements.append(Element(xVal: 1, yVal: -2, label: "4/1/2016"))
        elements.append(Element(xVal: 2, yVal: 2.7, label: "5/1/2016"))
        elements.append(Element(xVal: 3, yVal: 3.8, label: "6/1/2016"))
        elements.append(Element(xVal: 4, yVal: 1.75, label: "7/1/2016"))
        elements.append(Element(xVal: 5, yVal: 4.9, label: "8/1/2016"))
        elements.append(Element(xVal: 6, yVal: 6.9, label: "9/1/2016"))
        
        var parameters = ChartParameters()
        //parameters.yAxisMin = 0.5
        //parameters.yAxisMax = 10
        parameters.drawXaxisLabelsAtAngle = true
        
        barChart = BarChartView(frame: view.frame, dataSource: self, parameters: parameters, identifier: "testBarChart")
        view.addSubview(barChart)
        barChart.draw(barChart.frame)
        barChart.contentMode = .redraw
    }
    
    //add this to force redraw on device rotation
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        barChart.frame = view.bounds
        barChart.draw(barChart.frame)
    }
}

extension TestViewController : ChartDataSource {
    
    func dataCount(identifier: String) -> Int {
        return elements.count
    }
    
    func xValue(identifier: String, index: Int) -> Double {
        return elements[index].xVal
    }
    
    func yValue(identifier: String, index: Int) -> Double {
        return elements[index].yVal
    }
    
    func label(identifier: String, index: Int) -> String? {
        return elements[index].label
    }
}


