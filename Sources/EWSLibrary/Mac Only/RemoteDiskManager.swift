//
//  File.swift
//
//
//  Created by Eric Schramm on 7/7/21.
//

#if os(macOS)
import SwiftUI


public struct Credentials {
    let username: String
    let password: String
}

public protocol CredentialsStore {
    func set(_ value: String, for key: String)
    func get(_ key: String) -> String?
    func delete(_ key: String) -> Bool
}

/*  put inside project if using KeychainSwift
extension KeychainSwift : CredentialsStore {
    public func set(_ value: String, for key: String) {
        _ = set(value, forKey: key)
    }
}
*/

@available(macOS 12, *)
public actor RemoteDiskManager {
 
    public enum RemoteDiskManagerError : Error {
        case noPresentingViewControllerToCaptureCredentials
        case credentialsInvalid
        case mountingFailure(description: String)
        case fileSystemOverwriteFailure(description: String)
        case fileSystemError(description: String)
        case fileSizeCalculationError(description: String)
    }
    
    public enum ProcessType {
        case copy
        case move
        
        func actionTitle() -> String {
            switch self {
            case .copy:
                return "Copying"
            case .move:
                return "Moving"
            }
        }
    }
    
    // https://apple.stackexchange.com/questions/249627/programmatically-creating-mount-points-in-macos-10-12
    
    let localMountDir: String
    let testFile: String  // to validate access to drive
    let remoteIP: String
    let remoteDrivePath: String
    let credentialsStore: CredentialsStore
    
    let usernameKeyPrefix = "EWS-RDM-username"
    let passwordKeyPrefix = "EWS-RDM-password"
    
    let fileManagerQueue = DispatchQueue(label: "copyWithProgress")
    
    public init(credentialsStore: CredentialsStore, localMountDir: String? = nil, testFile: String? = nil, remoteIP: String? = nil, remoteDrivePath: String? = nil) {
        self.credentialsStore = credentialsStore
        self.localMountDir = localMountDir ?? "/Users/\(NSUserName())/mnt/"
        self.testFile = testFile ?? "/Apps/MakerManager.txt"
        self.remoteIP = remoteIP ?? "192.168.1.13"
        self.remoteDrivePath = remoteDrivePath ?? "TimeMachineBackup"
    }
    
    func testFilePath() -> String {
        return "\(localMountDir)\(testFile)"
    }
    
    func keychainUsernameKey() -> String {
        return "\(usernameKeyPrefix)-\(localMountDir)-\(remoteDrivePath)"
    }
    
    func keychainPasswordKey() -> String {
        return "\(passwordKeyPrefix)-\(localMountDir)-\(remoteDrivePath)"
    }
    
    func getCreds(presentingVC: NSViewController?) async throws -> Credentials {
        if let username = credentialsStore.get(keychainUsernameKey()), let password = credentialsStore.get(keychainPasswordKey()) {
            return Credentials(username: username, password: password)
        }
        guard let presentingVC = presentingVC else {
            throw RemoteDiskManagerError.noPresentingViewControllerToCaptureCredentials
        }
        
        let sheetVC = await MainActor.run {
            return NSViewController(nibName: nil, bundle: nil)
        }
        
        let credentials = try await withCheckedThrowingContinuation({ checkedContinuation in
            DispatchQueue.main.async {
                let credsView = NSHostingView(rootView: CredentialsView(title: "Enter credentials for remote disk \(self.remoteDrivePath)", handler: { result in
                    checkedContinuation.resume(with: result)
                    presentingVC.dismiss(sheetVC)
                }))
                credsView.frame = CGRect(x: 0, y: 0, width: 300, height: 180)
                sheetVC.view = credsView
                
                presentingVC.presentAsSheet(sheetVC)
            }
        })

        // save in keychain
        self.credentialsStore.set(credentials.username, for: self.keychainUsernameKey())
        self.credentialsStore.set(credentials.password, for: self.keychainPasswordKey())
    }
    
    public func nukeCreds() {
        _ = credentialsStore.delete(keychainUsernameKey())
        _ = credentialsStore.delete(keychainPasswordKey())
    }
    
    public func isMounted() -> Bool {
        return FileManager.default.fileExists(atPath: testFilePath())
    }
    
    public func mount(presentingVC: NSViewController?) async throws {
        guard !FileManager.default.fileExists(atPath: testFilePath()) else {
            return
        }
        
        let creds = try await getCreds(presentingVC: presentingVC)
            
        let shell = Shell()
        var output = shell.outputOf(commandName: "mkdir", arguments: ["-p", self.localMountDir]) ?? ""
        output += "; "
        output += shell.outputOf(commandName: "mount_smbfs", arguments: ["//\(creds.username):\(creds.password)@\(self.remoteIP)/\(self.remoteDrivePath)", self.localMountDir]) ?? ""
        if FileManager.default.fileExists(atPath: self.testFilePath()) {
            return
        } else {
            throw RemoteDiskManagerError.mountingFailure(description: output)
        }
    }
    
    public func unmount() {
        DispatchQueue.main.async {
            let shell = Shell()
            _ = shell.outputOf(commandName: "diskutil", arguments: ["unmount", self.localMountDir])
        }
    }
    
    public func processFile(presentingViewController: NSViewController?, type: ProcessType, overwrite: Bool, fromURL: URL, toURL: URL, statusUpdater: @escaping (String) -> ()) async throws {
        try await mount(presentingVC: presentingViewController)
        
        let fileManager = FileManager()
        do {
            switch type {
            case .copy:
                statusUpdater("Attempting copy from \(fromURL) to \(toURL)")
                try fileManager.copyItem(at: fromURL, to: toURL)
            case .move:
                statusUpdater("Attempting move from \(fromURL) to \(toURL)")
                try fileManager.moveItem(at: fromURL, to: toURL)
            }
        } catch let error as NSError {
            if error.code == 516, overwrite {
                do {
                    statusUpdater("Attempting removal before copy \(toURL)")
                    try fileManager.removeItem(at: toURL)
                    switch type {
                    case .copy:
                        statusUpdater("Attempting copy from \(fromURL) to \(toURL)")
                        try fileManager.copyItem(at: fromURL, to: toURL)
                    case .move:
                        statusUpdater("Attempting move from \(fromURL) to \(toURL)")
                        try fileManager.moveItem(at: fromURL, to: toURL)
                    }
                } catch {
                    throw RemoteDiskManagerError.fileSystemOverwriteFailure(description: error.localizedDescription)
                }
            } else {
                throw RemoteDiskManagerError.fileSystemError(description: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    public func processFileUpdatingProgressBar(presentingViewController: NSViewController?, type: ProcessType, overwrite: Bool, fromURL: URL, toURL: URL, actionDetailOverride: String?, statusUpdater: @escaping (String) -> ()) async throws {
        
        var spv: NSViewController?
        var progress: ObservableProgress?
        
        try await mount(presentingVC: presentingViewController)
        if let totalFileSize = try? await self.fileSize(at: fromURL) {
            let title = actionDetailOverride ?? "\(type.actionTitle()) File"
            progress = ObservableProgress(current: 0, total: totalFileSize, title: title, progressBarTitleStyle: .automatic(showRawUnits: true, showEstTotalTime: true))
            if let pvc = presentingViewController {
                spv = SimpleProgressWindow.present(presentingVC: pvc, presentationStyle: .modalSheet, progress: progress!)
            }
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer) in
                // called every 0.1 sec to assess progress of copy operation
                Task {
                    if let copiedFileSize = try? await self.fileSize(at: toURL) {
                        DispatchQueue.main.async {
                            progress?.update(current: copiedFileSize)
                            if copiedFileSize >= totalFileSize {
                                timer.invalidate()
                                spv?.dismiss(nil)
                                return
                            }
                        }
                    }
                }
            }
            
            self.fileManagerQueue.async {
                let fileManager = FileManager()
                do {
                    switch type {
                    case .copy:
                        statusUpdater("Attempting copy from \(fromURL) to \(toURL)")
                        try fileManager.copyItem(at: fromURL, to: toURL)
                    case .move:
                        statusUpdater("Attempting move from \(fromURL) to \(toURL)")
                        try fileManager.moveItem(at: fromURL, to: toURL)
                    }
                } catch let error as NSError {
                    if error.code == 516, overwrite {
                        do {
                            statusUpdater("Attempting removal before copy \(toURL)")
                            try fileManager.removeItem(at: toURL)
                            switch type {
                            case .copy:
                                statusUpdater("Attempting copy from \(fromURL) to \(toURL)")
                                try fileManager.copyItem(at: fromURL, to: toURL)
                            case .move:
                                statusUpdater("Attempting move from \(fromURL) to \(toURL)")
                                try fileManager.moveItem(at: fromURL, to: toURL)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                spv?.dismiss(nil)
                            }
                            throw RemoteDiskManagerError.fileSystemOverwriteFailure(description: error.localizedDescription)
                        }
                    } else {
                        DispatchQueue.main.async {
                            spv?.dismiss(nil)
                        }
                        throw RemoteDiskManagerError.fileSystemError(description: error.localizedDescription)
                    }
                }
            }
            timer.fire()
        }
    }

    
    public func fileSize(at url: URL) throws -> Int {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw RemoteDiskManagerError.fileSizeCalculationError(description: "No file exists for \(url.path), returning zero bytes")
        }
        if isDirectory.boolValue {
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                var sizeToReturn = 0
                for item in enumerator {
                    if let urlItem = item as? URL {
                        var isUrlItemDirectory: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: urlItem.path, isDirectory: &isUrlItemDirectory) else {
                            throw RemoteDiskManagerError.fileSizeCalculationError(description: "No file exists for \(urlItem.path), returning zero bytes")
                        }
                        guard !isUrlItemDirectory.boolValue else { continue }
                        let size = try (FileManager.default.attributesOfItem(atPath: urlItem.path)[.size] as? Int ?? 0)
                        //print("returning size of url \(urlItem.lastPathComponent) - \(numberFormatter.string(for: size)!)")
                        sizeToReturn += size
                    } else {
                        throw RemoteDiskManagerError.fileSizeCalculationError(description: "Cannot make URL for enumerator item \(url.path)")
                    }
                }
                return sizeToReturn
            } else {
                throw RemoteDiskManagerError.fileSizeCalculationError(description: "Cannot make enumerator for URL \(url.path)")
            }
        } else {
            let size = try (FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0)
            //print("returning size of url \(url.lastPathComponent) - \(numberFormatter.string(for: size)!)")
            return size
        }
    }
}

@available(macOS 12, *)
struct CredentialsView: View {
    
    let title: String
    let usernameTitle: String
    let buttonTitle: String
    let handler: (Result<Credentials, RemoteDiskManager.RemoteDiskManagerError>) -> ()
    
    @State private var username: String = ""
    @State private var password: String = ""
    
    init(title: String, usernameTitle: String = "Username", buttonTitle: String = "Log in", handler: @escaping (Result<Credentials, RemoteDiskManager.RemoteDiskManagerError>) -> ()) {
        self.title = title
        self.usernameTitle = usernameTitle
        self.buttonTitle = buttonTitle
        self.handler = handler
    }
    
    var body: some View {
        VStack() {
            Text(title)
                .multilineTextAlignment(.center)
                .padding(.vertical)
            HStack() {
                Spacer(minLength: 20)
                TextField(usernameTitle, text: $username)
                Spacer(minLength: 20)
            }
            HStack() {
                Spacer(minLength: 20)
                SecureField("Password", text: $password)
                Spacer(minLength: 20)
            }
            
            Button(action: {
                handler(.success(Credentials(username: username, password: password)))
            }){
                Text(buttonTitle)
            }
            .disabled(username.isEmpty || password.isEmpty)
            .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .frame(maxWidth: 300, maxHeight: 200)
    }
}

@available(macOS 12, *)
struct CredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        CredentialsView(title: "Please provide login information for TimeMachineBackup", usernameTitle: "Username") { creds in print(creds) }
    }
}
#endif
