//
//  File.swift
//  
//
//  Created by Eric Schramm on 1/31/24.
//

import Foundation
import SwiftUI

public enum LoadingResult<T> {
    case loading
    case success(T)
    case failure(Error)
}

//
//  ErrorHandling.swift
//  MDHExportTools
//
//  Created by Eric Schramm on 1/4/24.
//

struct ErrorAlert: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var dismissAction: (() -> Void)?
}

@MainActor
public class ErrorHandling: ObservableObject {
    
    public struct ErrorLoggerModel {
        public let error: Error
        public let title: String?
        public let prefix: String?
    }
    
    @Published var currentAlert: ErrorAlert?
    
    /// can use this to prevent an error doom loop where using onChange of appearsActive to trigger an event that is erroring out
    public var lastErrorClosed: Date?

    public static var externalErrorLoggerHandler: ((ErrorLoggerModel) -> ())? = nil
    
    public func handle(error: Error, title: String?, prefix: String?) {
        let message: String
        if let prefix {
            message = "\(prefix) - \(error)"
        } else {
            message = "\(error)"
        }
        Self.externalErrorLoggerHandler?(.init(error: error, title: title, prefix: prefix))
        DispatchQueue.main.async {
            self.currentAlert = ErrorAlert(title: title ?? "Error", message: message)
        }
        if let title {
            print("Error: \(title) - \(message)")
        } else {
            print("Error: \(message)")
        }
    }
    
    public func handleMessage(title: String, message: String) {
        DispatchQueue.main.async {
            self.currentAlert = ErrorAlert(title: title, message: message)
        }
    }
}

@available(iOS 14.0, *)
struct HandleErrorsByShowingAlertViewModifier: ViewModifier {
    @StateObject var errorHandling = ErrorHandling()

    func body(content: Content) -> some View {
        content
            .environmentObject(errorHandling)
            // Applying the alert for error handling using a background element
            // is a workaround, if the alert would be applied directly,
            // other .alert modifiers inside of content would not work anymore
            .background(
                EmptyView()
                    .alert(item: $errorHandling.currentAlert) { currentAlert in
                        Alert(
                            title: Text(currentAlert.title),
                            message: Text(currentAlert.message),
                            dismissButton: .default(Text("OK")) {
                                errorHandling.lastErrorClosed = Date()
                                currentAlert.dismissAction?()
                            }
                        )
                    }
            )
    }
}

extension View {
    @available(iOS 14.0, *)
    public func withErrorHandling() -> some View {
        modifier(HandleErrorsByShowingAlertViewModifier())
    }
}

public struct AsyncText: View {

    public enum LoadingStyle {
        case empty
        case loadingIndicator
    }
    
    public let loadingStyle: LoadingStyle
    
    /// used to ensure ASyncText is reconstructed if linked item changes
    public let uniqueKey: String
    @State private var string: String? = nil
    
    public let loadingClosure: () async -> String
    
    public init(loadingStyle: LoadingStyle, string: String? = nil, uniqueKey: String, loadingClosure: @escaping () async -> String) {
        self.loadingStyle = loadingStyle
        self.string = string
        self.uniqueKey = uniqueKey
        self.loadingClosure = loadingClosure
    }
    
    public var body: some View {
        VStack {
            if let string {
                Text(string)
            } else {
                switch loadingStyle {
                case .empty:
                    EmptyView()
                case .loadingIndicator:
                    ProgressView()
                }
            }
        }
        .task(id: uniqueKey) {
            string = await loadingClosure()
        }
    }
}

/*
 Order of superSet is stable.
 Order of subSet is stable to the sort order of superSet.
 */

@available(macOS 14.0, *)
public struct SubsetPickerView<T : Identifiable>: View {
    
    let fullSuperSet: [T]
    let setDict: [T.ID : T]
    let display: (T) -> String
    
    @State private var currentSuperSet: [T]
    @Binding var currentSubSet: [T]
    
    let superSetTitle: String
    let subSetTitle: String
    
    @State private var superSetSelection: T.ID? = nil
    @State private var subSetSelection: T.ID? = nil
    
    public init(fullSuperSet: [T], subSet: Binding<[T]>, superSetTitle: String, subSetTitle: String, display: @escaping (T) -> String) {
        self.fullSuperSet = fullSuperSet
        self.setDict = fullSuperSet.reduce([T.ID : T](), { partialResult, item in
            var dict = partialResult
            dict[item.id] = item
            return dict
        })
        self._currentSubSet = subSet
        self.currentSuperSet = fullSuperSet
            .filter({ !Set(subSet.wrappedValue.map(\.id)).contains($0.id) })
        self.superSetTitle = superSetTitle
        self.subSetTitle = subSetTitle
        self.display = display
    }
    
    public var body: some View {
        VStack {
            HStack {
                Table(currentSuperSet, selection: $superSetSelection) {
                    TableColumn(superSetTitle) { item in
                        Text(display(item))
                    }
                }
                VStack {
                    Spacer()
                    
                    Button {
                        let selectedItem = setDict[superSetSelection!]!
                        // to keep sort order, refilter
                        currentSubSet.append(selectedItem)
                        currentSubSet = fullSuperSet
                            .filter({ Set(currentSubSet.map(\.id)).contains($0.id) })
                        currentSuperSet = currentSuperSet.filter { $0.id != selectedItem.id }
                    } label: {
                        Image(systemName: "chevron.right.2")
                    }
                    .disabled(superSetSelection == nil)
                    
                    Button {
                        let selectedItem = setDict[subSetSelection!]!
                        // to keep sort order, refilter
                        currentSubSet = currentSubSet.filter { $0.id != selectedItem.id }
                        currentSuperSet = fullSuperSet
                            .filter({ !Set(currentSubSet.map(\.id)).contains($0.id) })
                    } label: {
                        Image(systemName: "chevron.left.2")
                    }
                    .disabled(subSetSelection == nil)
                    
                    Spacer()
                }
                Table(currentSubSet, selection: $subSetSelection) {
                    TableColumn(subSetTitle) { item in
                        Text(display(item))
                    }
                }
            }
        }
        .padding()
        .onChange(of: superSetSelection) { oldValue, newValue in
            if newValue != nil {
                subSetSelection = nil
            }
        }
        .onChange(of: subSetSelection) { oldValue, newValue in
            if newValue != nil {
                superSetSelection = nil
            }
        }
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies the given transform if the given condition evaluates to `true` and applies an alternate if `false`
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    ///   - elseTransform: The transform to apply if conidition false
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder public func ifElse<Content: View>(_ condition: Bool, transform: (Self) -> Content, elseTransform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}

#if os(iOS)
// https://stackoverflow.com/questions/59745663/is-there-a-swiftui-equivalent-for-viewwilldisappear-or-detect-when-a-view-is
struct WillDisappearHandler: UIViewControllerRepresentable {
    func makeCoordinator() -> WillDisappearHandler.Coordinator {
        Coordinator(onWillDisappear: onWillDisappear)
    }

    let onWillDisappear: () -> Void

    func makeUIViewController(context: UIViewControllerRepresentableContext<WillDisappearHandler>) -> UIViewController {
        context.coordinator
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<WillDisappearHandler>) {
    }

    typealias UIViewControllerType = UIViewController

    class Coordinator: UIViewController {
        let onWillDisappear: () -> Void

        init(onWillDisappear: @escaping () -> Void) {
            self.onWillDisappear = onWillDisappear
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onWillDisappear()
        }
    }
}

extension View {
    public func onWillDisappear(_ perform: @escaping () -> Void) -> some View {
        background(WillDisappearHandler(onWillDisappear: perform))
    }
}
#endif
