//
//  ProgressMonitor.swift
//  TestProgress
//
//  Created by Eric Schramm on 7/14/21.
//

#if os(macOS)
import SwiftUI

@available(macOS 12, *)
public struct SimpleProgressWindow {
    
    public enum PresentationStyle {
        case modalSheet
        case modalWindow
    }
    
    @MainActor
    public static func present(presentingVC: NSViewController, presentationStyle: PresentationStyle, progress: ObservableProgress, windowSize: CGSize = CGSize(width: 600, height: 180)) -> NSViewController {
        let sheetVC = NSViewController(nibName: nil, bundle: nil)
        let progressView = NSHostingView(rootView: ESProgressView(observableProgress: progress))
        progressView.frame = CGRect(origin: .zero, size: windowSize)
        sheetVC.view = progressView
        
        switch presentationStyle {
        case .modalSheet:
            presentingVC.presentAsSheet(sheetVC)
        case .modalWindow:
            presentingVC.presentAsModalWindow(sheetVC)
        }
        return sheetVC
    }
}

@available(macOS 12, *)
@MainActor
public class ObservableProgress : ObservableObject {
    
    public enum ProgressBarTitleStyle {
        case automatic(showRawUnits: Bool, showEstTotalTime: Bool)
        case custom(String)
    }
    
    struct Update {
        let current: Int
        let total: Int
        let title: String
        let progressBarTitleStyle: ProgressBarTitleStyle
    }
    
    @Published private(set) var current: Int
    @Published private(set) var total: Int
    @Published private(set) var title: String
    @Published private(set) var progressBarTitle: String

    var nextUpdate: Update?
    private(set) var progressBarTitleStyle: ProgressBarTitleStyle
    
    var profiler: ProgressTimeProfiler
    let limiter = Limiter(policy: .throttleThenDebounce, duration: 0.5)
    
    public init(current: Int, total: Int, title: String, progressBarTitleStyle: ProgressBarTitleStyle) {
        self.current = current
        self.total = total
        self.title = title
        
        self.profiler = ProgressTimeProfiler(totalWorkUnits: Int(total), lastResultWeight: 0)
        
        self.progressBarTitleStyle = progressBarTitleStyle
        switch progressBarTitleStyle {
        case .automatic(_,_):
            self.progressBarTitle = ""
        case .custom(let title):
            self.progressBarTitle = title
        }
    }
    
    public func update(current: Int, total: Int? = nil, title: String? = nil, progressBarTitleStyle: ProgressBarTitleStyle? = nil) {
        DispatchQueue.main.async {
            self.nextUpdate = Update(current: current, total: total ?? self.nextUpdate?.total ?? self.total, title: title ?? self.nextUpdate?.title ?? self.title, progressBarTitleStyle: progressBarTitleStyle ?? self.nextUpdate?.progressBarTitleStyle ?? self.progressBarTitleStyle)
            Task {
                await self.limiter.submit(operation: { await self.applyUpdate() })
            }
        }
    }
    
    public func resetProgressProfiler() {
        self.profiler = ProgressTimeProfiler(totalWorkUnits: Int(total), lastResultWeight: 0)
    }
    
    func applyUpdate() {
        DispatchQueue.main.async {
            if let next = self.nextUpdate {
                self.total = next.total
                self.current = next.current
                self.profiler.totalWork = next.total
                self.title = next.title
                
                switch next.progressBarTitleStyle {
                case .automatic(showRawUnits: let showRawUnits, showEstTotalTime: let showEstTotalTime):
                    self.profiler.stamp(withWorkUnitsComplete: Int(next.current))
                    self.progressBarTitle = self.profiler.progress(showRawUnits: showRawUnits, showEstTotalTime: showEstTotalTime)
                case .custom(let title):
                    self.progressBarTitle = title
                }
            }
        }
    }
}

@available(macOS 12, *)
public struct ESProgressView: View {
    
    @ObservedObject var observableProgress: ObservableProgress
    
    public init(observableProgress: ObservableProgress) {
        self.observableProgress = observableProgress
    }
    
    public var body: some View {
        VStack {
            Text(observableProgress.title).padding(.bottom, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
            ProgressView(observableProgress.progressBarTitle, value: Double(observableProgress.current), total: Double(observableProgress.total))
        }
        .padding(.all, 20)
    }
}

#if DEBUG

struct TestProgressView: View {
    
    @StateObject var observableProgress = ObservableProgress(current: 0, total: 0, title: "Test Example", progressBarTitleStyle: .automatic(showRawUnits: true, showEstTotalTime: true))
    
    var body: some View {
        VStack {
            //ESProgressView(observableProgress: ObservableProgress(current: 23, total: 100, title: "This is the title", progressBarTitleStyle: .custom("Downloading...")))
            ESProgressView(observableProgress: observableProgress)
            Button {
                Task {
                    await startJob()
                }
            } label: {
                Text("Start")
            }

        }.padding()
    }
    
    func startJob() async {
        for n in 0..<100 {
            try! await Task.sleep(nanoseconds: 100_000_000)
            observableProgress.update(current: n + 1, total: 100)
        }
    }
}

@available(macOS 12, *)
#Preview {
    TestProgressView()
}
#endif
#endif
