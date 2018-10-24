//
//  Chart.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 10/12/18.
//  Copyright © 2018 eware. All rights reserved.
//

import Foundation
import CoreGraphics

public protocol ChartDataSource {
    func dataCount(identifier: String) -> Int
    func xValue(identifier: String, index: Int) -> Double
    func yValue(identifier: String, index: Int) -> Double
    func label(identifier: String, index: Int) -> String?
}

public protocol CocoaViewable {
    var frame: Frameable { get set }
    var isAppKit: Bool { get }
}
public protocol Frameable {
    var origin: Originable { get set }
    var size: Sizeable { get set }
}
public protocol Originable {
    var x: CGFloat { get set }
    var y: CGFloat { get set }
}
public protocol Sizeable {
    var width: CGFloat { get set }
    var height: CGFloat { get set }
}

protocol AxisDrawable {
    func drawAxis(from: CGPoint, to: CGPoint, width: CGFloat, colorAlpha: CGFloat)
    func drawAxisStepLabel(label: String, atPoint: CGPoint)
}

struct Frame: Frameable {
    var origin: Originable
    var size: Sizeable
}
struct Origin: Originable {
    var x: CGFloat
    var y: CGFloat
}
struct Size: Sizeable {
    var height: CGFloat
    var width: CGFloat
}

public struct ChartParameters {
    public var xAxis = Axis()
    public var yAxis = Axis()
    public var barWidthFactor: CGFloat = 0.75
    public var drawXaxisLabelsAtAngle = false
    
    public init() {
        self.xAxis = Axis()
        self.yAxis = Axis()
        barWidthFactor = 0.75
        drawXaxisLabelsAtAngle = false
    }
}

public struct Axis {
    public var xPadding: CGFloat = 15
    public var yPadding: CGFloat = 15
    public var width: CGFloat = 6
    public var min: CGFloat!
    public var max: CGFloat!
    public var anchorAxisAt0unlessNegative = true
}

struct ChartCalculations {  //should be reusable for UIKit and AppKit, can assume isAppKit to flip y-axis if needed
    
    let dataSource: ChartDataSource
    var cocoaView: CocoaViewable {
        didSet {
            if chartType == .bar {
                evenDistributionBarWidth = (cocoaView.frame.size.width - (2 * parameters.xAxis.xPadding) - parameters.xAxis.width) / CGFloat(dataCount)
            }
        }
    }
    let chartType: ChartType
    let chartScaling: ChartScaling
    var parameters: ChartParameters = ChartParameters()
    let chartIdentifier: String
    
    let dataCount: Int
    
    //Bar parameters
    
    var evenDistributionBarWidth: CGFloat!
    
    struct ChartScaling {
        let xMin: CGFloat
        let xMax: CGFloat
        let yMin: CGFloat
        let yMax: CGFloat
    }
    
    enum ChartType {
        case bar
        case line
    }
    
    init(dataSource: ChartDataSource, cocoaView: CocoaViewable, chartType: ChartType, parameters: ChartParameters?, identifier: String) {
        
        evenDistributionBarWidth = nil
        
        self.dataSource = dataSource
        self.chartType = chartType
        self.cocoaView = cocoaView
        self.chartIdentifier = identifier
        if let parameters = parameters {
            self.parameters = parameters
        } else {
            self.parameters = ChartParameters()
        }
        
        var minXvalue: Double = Double.greatestFiniteMagnitude
        var maxXvalue: Double = Double.leastNormalMagnitude
        var minYvalue: Double = Double.greatestFiniteMagnitude
        var maxYvalue: Double = Double.leastNormalMagnitude
        
        self.dataCount = dataSource.dataCount(identifier: chartIdentifier)
        
        for index in 0..<dataCount {
            
            let xValue = dataSource.xValue(identifier: identifier, index: index)
            let yValue = dataSource.yValue(identifier: identifier, index: index)
            
            if xValue < minXvalue {
                minXvalue = xValue
            }
            if xValue > maxXvalue {
                maxXvalue = xValue
            }
            
            if yValue < minYvalue {
                minYvalue = yValue
            }
            if yValue > maxYvalue {
                maxYvalue = yValue
            }
        }
        
        let xSpanFactor = (maxXvalue - minXvalue) * 0.05
        let ySpanFactor = (maxYvalue - minYvalue) * 0.05
        
        //auto-size axes max/mins
        
        if self.parameters.xAxis.max == nil {
            self.parameters.xAxis.max = CGFloat(maxXvalue + xSpanFactor)
        }
        if self.parameters.yAxis.max == nil {
            self.parameters.yAxis.max = CGFloat(maxYvalue + ySpanFactor)
        }
        
        self.chartScaling = ChartScaling(xMin: CGFloat(minXvalue), xMax: CGFloat(maxXvalue), yMin: CGFloat(minYvalue), yMax: CGFloat(maxYvalue))
        
        if self.parameters.xAxis.min == nil {
            if minXvalue < 0 || !self.parameters.xAxis.anchorAxisAt0unlessNegative {
                self.parameters.xAxis.min = (minXvalue < 0) ? CGFloat(minXvalue + xSpanFactor) : CGFloat(minXvalue - xSpanFactor)
            } else {
                self.parameters.xAxis.min = 0
            }
        }
        
        if self.parameters.yAxis.min == nil {
            if minYvalue < 0 || !self.parameters.yAxis.anchorAxisAt0unlessNegative {
                self.parameters.yAxis.min = (minYvalue < 0) ? CGFloat(minYvalue + ySpanFactor) : CGFloat(minYvalue - ySpanFactor)
            } else {
                self.parameters.yAxis.min = 0
            }
        }
    }
    
    //LINE AND BAR
    
    func yRatio(for chartValue: CGFloat) -> CGFloat {
        return (chartValue - parameters.yAxis.min) / (parameters.yAxis.max - parameters.yAxis.min)
    }
    func xRatio(for chartValue: CGFloat) -> CGFloat {
        return (chartValue - parameters.xAxis.min) / (parameters.xAxis.max - parameters.xAxis.min)
    }
    func chartHeight() -> CGFloat {
        return cocoaView.frame.size.height - (parameters.xAxis.yPadding + parameters.yAxis.yPadding)
    }
    func chartWidth() -> CGFloat {
        return cocoaView.frame.size.width - (parameters.xAxis.xPadding + parameters.yAxis.xPadding)
    }
    
    func yValueCalculated(for chartValue: CGFloat) -> CGFloat {
        if cocoaView.isAppKit {
            return yRatio(for: chartValue) * chartHeight() + parameters.xAxis.yPadding
        } else {
            return cocoaView.frame.size.height - parameters.xAxis.yPadding - (yRatio(for: chartValue) * chartHeight()) - parameters.xAxis.width
        }
    }
    
    func xValueCalculated(for chartValue: CGFloat) -> CGFloat {
        if cocoaView.isAppKit {
            return xRatio(for: chartValue) * chartWidth() + parameters.yAxis.xPadding
        } else {
            return cocoaView.frame.size.width - parameters.yAxis.xPadding - (xRatio(for: chartValue) * chartWidth()) - parameters.yAxis.width
        }
    }
    
    func drawAxes(drawer: AxisDrawable) {
        
        let yAxisFromPoint: CGPoint
        let yAxisToPoint: CGPoint
        
        if cocoaView.isAppKit {
            yAxisFromPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: parameters.yAxis.yPadding + parameters.yAxis.width / 2)
            yAxisToPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: cocoaView.frame.size.height - parameters.yAxis.yPadding - parameters.yAxis.width / 2)
        } else {
            yAxisFromPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: parameters.yAxis.yPadding)
            yAxisToPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: cocoaView.frame.size.height - parameters.yAxis.yPadding)
        }
        if parameters.yAxis.width > 0 {
            drawer.drawAxis(from: yAxisFromPoint, to: yAxisToPoint, width: parameters.yAxis.width, colorAlpha: 1)
        }
        
        let xAxisYval = yValueCalculated(for: 0)  //exact center
        
        let xAxisFromPoint = CGPoint(x: parameters.xAxis.xPadding, y: xAxisYval)
        let xAxisToPoint = CGPoint(x: cocoaView.frame.size.width - parameters.xAxis.xPadding, y: xAxisYval)
        if parameters.xAxis.width > 0 {
            drawer.drawAxis(from: xAxisFromPoint, to: xAxisToPoint, width: parameters.xAxis.width, colorAlpha: 1)
        }
        
        //Y-Axis Steps
        
        guard parameters.yAxis.width > 0 else { return }
        
        let differenceFromMinToMax = chartScaling.yMax - chartScaling.yMin
        
        let suggestedSteps = differenceFromMinToMax / 3
        
        var maxFractionDigits: Int = 0
        var roundingIncrement: Double = 0
        
        if suggestedSteps > 0.5 {
            maxFractionDigits = 1
            roundingIncrement = 0.5
        } else if suggestedSteps > 0.2 {
            maxFractionDigits = 2
            roundingIncrement = 0.2
        } else {
            maxFractionDigits = 3
            roundingIncrement = 0.1
        }
        
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = maxFractionDigits
        numberFormatter.roundingIncrement = NSNumber(value: roundingIncrement)
        
        var yStop: CGFloat = 0
        let stopWidth = parameters.yAxis.width * 0.5
        
        if parameters.yAxis.min < 0 && parameters.yAxis.max > 0 {  //straddles zero axis
            
            for _ in 1...6 {
                
                let yStopRoundedText = numberFormatter.string(for: yStop)!
                yStop = CGFloat(numberFormatter.number(from: yStopRoundedText)!.floatValue)
                
                if yStop < parameters.yAxis.max && yStop > parameters.yAxis.min {
                    let yPosition = yValueCalculated(for: yStop)
                    let fromPoint = CGPoint(x: cocoaView.frame.size.width - parameters.yAxis.xPadding, y: yPosition)
                    let toPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: yPosition)
                    drawer.drawAxis(from: fromPoint, to: toPoint, width: stopWidth, colorAlpha: 0.3)
                    
                    drawer.drawAxisStepLabel(label: yStopRoundedText, atPoint: CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width + 3, y: yPosition + 3))
                }
                
                if -yStop < parameters.yAxis.max && -yStop > parameters.yAxis.min {
                    let yPosition = yValueCalculated(for: -yStop)
                    let fromPoint = CGPoint(x: cocoaView.frame.size.width - parameters.yAxis.xPadding, y: yPosition)
                    let toPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: yPosition)
                    drawer.drawAxis(from: fromPoint, to: toPoint, width: stopWidth, colorAlpha: 0.3)
                    
                    drawer.drawAxisStepLabel(label: yStopRoundedText, atPoint: CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width + 3, y: yPosition + 3))
                }
                
                yStop += suggestedSteps
            }
        } else {  // starts or ends at zero
            
            for _ in 1...6 {
                
                let yStopRoundedText = numberFormatter.string(from: NSNumber(value: Float(yStop)))!
                yStop = CGFloat(numberFormatter.number(from: yStopRoundedText)!.floatValue)
                
                if yStop < parameters.yAxis.max && yStop > parameters.yAxis.min {
                    let yPosition = yValueCalculated(for: yStop)
                    let fromPoint = CGPoint(x: cocoaView.frame.size.width - parameters.yAxis.xPadding, y: yPosition)
                    let toPoint = CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width / 2, y: yPosition)
                    drawer.drawAxis(from: fromPoint, to: toPoint, width: stopWidth, colorAlpha: 0.3)
                    
                    drawer.drawAxisStepLabel(label: yStopRoundedText, atPoint: CGPoint(x: parameters.yAxis.xPadding + parameters.yAxis.width + 3, y: yPosition + 3))
                }
                
                if parameters.yAxis.min == 0 {
                    yStop += suggestedSteps
                } else {
                    yStop -= suggestedSteps
                }
            }
        }
    }
    
    
    /*
     func xValueCalculated(for chartValue: CGFloat, xAxisMin: CGFloat, xAxisMax: CGFloat, xPadding: CGFloat) -> CGFloat {
     return ((chartValue - xAxisMin) / (xAxisMax - xAxisMin) * (frame.size.width - xPadding * 2) + xPadding)
     }*/
    
    //BAR
    
    func barOrigin(index: Int) -> Originable {
        let xOffset = evenDistributionBarWidth * ((1 - parameters.barWidthFactor) / 2)
        let x = parameters.yAxis.xPadding + parameters.yAxis.width + CGFloat(index) * evenDistributionBarWidth + xOffset
        let y: CGFloat
        let dataValue = CGFloat(dataSource.yValue(identifier: chartIdentifier, index: index))
        if cocoaView.isAppKit {
            if dataValue > 0 {
                y = yValueCalculated(for: 0) + parameters.yAxis.width / 2
            } else {
                y = yValueCalculated(for: dataValue)
            }
        } else {
            if dataValue > 0 {
                y = yValueCalculated(for: dataValue)
            } else {
                y = yValueCalculated(for: 0) + parameters.yAxis.width / 2
            }
        }
        return Origin(x: x, y: y)
    }
    
    func barSize(index: Int) -> Sizeable {
        let width = evenDistributionBarWidth * parameters.barWidthFactor
        let height = abs(yValueCalculated(for: CGFloat(dataSource.yValue(identifier: chartIdentifier, index: index))) - yValueCalculated(for: 0)) - parameters.xAxis.width / 2
        return Size(height: height, width: width)
    }
    
    //LINE
    
    func linePoint(index: Int) -> Originable {
        return Origin(x: xValueCalculated(for: CGFloat(dataSource.xValue(identifier: chartIdentifier, index: index))), y: yValueCalculated(for: CGFloat(dataSource.yValue(identifier: chartIdentifier, index: index))))
    }
    
}
