//
//  ReleaseNotesView.swift
//  EWSLibrary
//
//  SwiftUI replacement for the UIKit `AppReleaseNotesVC` "what's new" popup.
//  The reusable chrome (title + Close) lives here and is localized against the
//  package bundle (`bundle: #bundle`); the per-app, per-version bullet content
//  is injected by the host app as `[LocalizedStringResource]`, so it resolves
//  against that app's catalog. Present it however you like — it's designed to
//  be dropped straight into a `.sheet`.
//

#if os(iOS)
import SwiftUI

public struct ReleaseNotesView: View {

    private let version: String
    private let notes: [LocalizedStringResource]
    private let onClose: () -> Void

    /// - Parameters:
    ///   - version: Display version string (e.g. `CFBundleShortVersionString`).
    ///   - notes: The app's release-note bullets for this version. Define these
    ///     as string literals in the host app so Xcode extracts them into the
    ///     app's String Catalog.
    ///   - onClose: Invoked when the user taps Close (e.g. flip the sheet's binding).
    public init(version: String,
                notes: [LocalizedStringResource],
                onClose: @escaping () -> Void) {
        self.version = version
        self.notes = notes
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Interpolating `version` yields the catalog format "What's new in version %@".
            Text("What's new in version \(version)", bundle: #bundle,
                 comment: "Release-notes popup title; the placeholder is the app version number.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: "•")
                            Text(note)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            Divider()

            Button {
                onClose()
            } label: {
                Text("Close", bundle: #bundle,
                     comment: "Button that dismisses the what's-new release notes.")
            }
        }
        .padding(20)
    }
}

/// First-launch / version-update tracking, factored out of `AppReleaseNotesVC`
/// so SwiftUI callers don't have to instantiate a view controller. Uses the
/// same UserDefaults key and stored-value format as the legacy VC, so an app
/// migrating from `AppReleaseNotesVC` to this type reads its existing state
/// seamlessly (no spurious "what's new" on the upgrade build).
public enum ReleaseNotesTracker {

    private static let versionKey = "AppReleaseNotes.VersionKey"

    /// `CFBundleShortVersionString` of the running app, for display.
    public static var currentShortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?"
    }

    /// `true` the very first time the app runs (no version stored yet). Stores
    /// the current version as a side effect so subsequent launches return `false`.
    public static func isAppOnFirstLaunch() -> Bool {
        let isFirstLaunch = UserDefaults.standard.string(forKey: versionKey) == nil
        if isFirstLaunch {
            storeCurrentVersion()
        }
        return isFirstLaunch
    }

    /// `true` when the current build differs from the last one seen. Stores the
    /// current version as a side effect when it has changed.
    public static func isAppVersionUpdated() -> Bool {
        guard let previous = UserDefaults.standard.string(forKey: versionKey) else {
            storeCurrentVersion()
            return true
        }
        guard let current = storedValue() else { return true }
        let isUpdated = current != previous
        if isUpdated {
            storeCurrentVersion()
        }
        return isUpdated
    }

    private static func storedValue() -> String? {
        guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return "\(build).\(short)"
    }

    private static func storeCurrentVersion() {
        guard let value = storedValue() else { return }
        UserDefaults.standard.setValue(value, forKey: versionKey)
    }
}
#endif
