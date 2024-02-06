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

public class ErrorHandling: ObservableObject {
    
    public struct ErrorLoggerModel {
        public let error: Error
        public let title: String?
        public let prefix: String?
    }
    
    @Published var currentAlert: ErrorAlert?

    public static var externalErrorLoggerHandler: ((ErrorLoggerModel) -> ())? = nil
    
    public func handle(error: Error, title: String?, prefix: String?) {
        let message: String
        if let prefix {
            message = "\(prefix) - \(error)"
        } else {
            message = "\(error)"
        }
        Self.externalErrorLoggerHandler?(.init(error: error, title: title, prefix: prefix))
        currentAlert = ErrorAlert(title: title ?? "Error", message: message)
        if let title {
            print("Error: \(title) - \(message)")
        } else {
            print("Error: \(message)")
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
