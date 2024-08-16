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
public class ObservableProgress : ObservableObject, Identifiable, @preconcurrency Equatable, @preconcurrency Hashable {
    
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
    @Published public private(set) var isActive: Bool
    
    weak var parent: ObservableProgress?
    @Published public private(set) var children: [ObservableProgress] = []

    var nextUpdate: Update?
    private(set) var progressBarTitleStyle: ProgressBarTitleStyle
    
    var profiler: ProgressTimeProfiler
    let limiter = Limiter(policy: .throttleThenDebounce, duration: 0.5)
    
    public init(current: Int, total: Int, title: String, progressBarTitleStyle: ProgressBarTitleStyle) {
        self.current = current
        self.total = total
        self.title = title
        self.isActive = (total > 0)
        
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
        let superTotal = nextUpdate?.total ?? self.total
        if let parent {
            let superCurrent = nextUpdate?.current ?? self.current
            let currentDiff = current - superCurrent
            let totalDiff = (total == nil) ? 0 : (total! - superTotal)
            parent.updateDiff(currentDiff: currentDiff, totalDiff: totalDiff)
        }
        
        self.nextUpdate = Update(current: current, total: total ?? superTotal, title: title ?? self.nextUpdate?.title ?? self.title, progressBarTitleStyle: progressBarTitleStyle ?? self.nextUpdate?.progressBarTitleStyle ?? self.progressBarTitleStyle)
        Task { @MainActor in
            await self.limiter.submit(operation: { await self.applyUpdate() })
        }
    }
    
    public func updateDiff(currentDiff: Int, totalDiff: Int) {
        let nextCurrent = (nextUpdate?.current ?? self.current) + currentDiff
        let nextTotal = (nextUpdate?.total ?? self.total) + totalDiff
        update(current: nextCurrent, total: nextTotal)
    }
    
    public func addChild(_ child: ObservableProgress) {
        self.children.append(child)
        //current += child.current
        //total += child.total
        child.parent = self
        updateDiff(currentDiff: child.current, totalDiff: child.total)
    }
    
    func applyUpdate() {
        if let nextUpdate {
            total = nextUpdate.total
            current = nextUpdate.current
            profiler.totalWork = nextUpdate.total
            title = nextUpdate.title
            
            switch nextUpdate.progressBarTitleStyle {
            case .automatic(showRawUnits: let showRawUnits, showEstTotalTime: let showEstTotalTime):
                profiler.stamp(withWorkUnitsComplete: Int(nextUpdate.current))
                progressBarTitle = self.profiler.progress(showRawUnits: showRawUnits, showEstTotalTime: showEstTotalTime)
            case .custom(let title):
                progressBarTitle = title
            }
            isActive = (total > 0)
        }
    }
    
    public func resetForReuse() {
        profiler = ProgressTimeProfiler(totalWorkUnits: Int(total), lastResultWeight: 0)
        current = 0
        total = 0
        nextUpdate = nil
        isActive = false
        for child in children {
            child.parent = nil
        }
        children.removeAll()
    }
    
    public static func == (lhs: ObservableProgress, rhs: ObservableProgress) -> Bool {
        return lhs.current == rhs.current &&
        lhs.total == rhs.total &&
        lhs.title == rhs.title &&
        lhs.progressBarTitle == rhs.progressBarTitle
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

@available(macOS 12, *)
public struct ESProgressView: View {
    
    @ObservedObject var observableProgress: ObservableProgress
    let hideIfTotalWorkIsZero: Bool
    
    public init(observableProgress: ObservableProgress, hideIfTotalWorkIsZero: Bool = false) {
        self.observableProgress = observableProgress
        self.hideIfTotalWorkIsZero = hideIfTotalWorkIsZero
    }
    
    public var body: some View {
        if observableProgress.total > 0 {
            VStack {
                Text(observableProgress.title).padding(.bottom, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
                ProgressView(observableProgress.progressBarTitle, value: Double(observableProgress.current), total: Double(observableProgress.total))
            }
            .padding(.all, 20)
        } else {
            EmptyView()
        }
    }
}

// https://www.objc.io/blog/2019/12/16/drawing-trees/
/*
struct Tree<A> {
    var value: A
    var children: [Tree<A>] = []
    init(_ value: A, children: [Tree<A>] = []) {
        self.value = value
        self.children = children
    }
}

struct DiagramSimple<A: Identifiable, V: View>: View {
    let tree: Tree<A>
    let node: (A) -> V

    var body: some View {
        return VStack(alignment: .center) {
            node(tree.value)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(tree.children, id: \.value.id, content: { child in
                    DiagramSimple(tree: child, node: self.node)
                })
            }
        }
    }
}*/


/*
 Example usage:
 
 ProgressTree<ESProgressView>(tree: thing.rootProgress, node: { progress in
     ESProgressView(observableProgress: progress, hideIfTotalWorkIsZero: true)
 })
 
 */

@available(macOS 12, *)
public struct ProgressTree<V: View>: View {
    @StateObject var tree: ObservableProgress
    let node: (ObservableProgress) -> V
    
    public init(tree: ObservableProgress, node: @escaping (ObservableProgress) -> V) {
        _tree = StateObject(wrappedValue: tree)
        self.node = node
    }

    public var body: some View {
        return VStack(alignment: .center) {
            node(tree)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(tree.children, content: { child in
                    ProgressTree(tree: child, node: self.node)
                })
            }
        }
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
