//
//  Shell.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/23/18.
//  Copyright © 2018 eware. All rights reserved.
//

#if os(macOS)
import Foundation

//https://gist.github.com/andreacipriani/8c3af3719da31c8fae2cdfa8c21e17ba

public class Shell
{
    public enum StreamingOutput {
        case string(String)
        case complete
        case error(String)
    }
    
    public init() {}
    
    public func outputOf(commandName: String, arguments: [String] = [], runFromPath: String = "") -> String? {
        return bash(commandName: commandName, arguments:arguments, runFromPath: runFromPath)
    }
    
    public func streaming(commandName: String, arguments: [String] = [], runFromPath: String = "", handler: @escaping (StreamingOutput) -> ()) {
        guard var whichPathForCommand = executeShell(command: "/bin/bash" , arguments:[ "-l", "-c", "which \(commandName)" ], runFromPath: "") else {
            handler(.error("\(commandName) not found"))
            return
        }
        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        streamingExecuteShell(command: whichPathForCommand, arguments: arguments, runFromPath: runFromPath, handler: handler)
    }
    
    // MARK: private
    
    private func bash(commandName: String, arguments: [String], runFromPath: String) -> String? {
        guard var whichPathForCommand = executeShell(command: "/bin/bash" , arguments:[ "-l", "-c", "which \(commandName)" ], runFromPath: "") else {
            return "\(commandName) not found"
        }
        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        return executeShell(command: whichPathForCommand, arguments: arguments, runFromPath: runFromPath)
    }
    
    private func executeShell(command: String, arguments: [String] = [], runFromPath: String) -> String? {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        if !runFromPath.isEmpty {
            task.currentDirectoryPath = runFromPath
        }
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String? = String(data: data, encoding: String.Encoding.utf8)
        
        return output
    }
    
    private func streamingExecuteShell(command: String, arguments: [String] = [], runFromPath: String, handler: @escaping (StreamingOutput) -> ()) {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        if !runFromPath.isEmpty {
            task.currentDirectoryPath = runFromPath
        }
        
        NotificationCenter.default.addObserver(forName: FileHandle.readCompletionNotification, object: pipe.fileHandleForReading, queue: .main) { notification in
            let data = notification.userInfo![NSFileHandleNotificationDataItem] as! Data
            guard !data.isEmpty else {
                handler(.complete)
                return
            }
            (notification.object as! FileHandle).readInBackgroundAndNotify()
            handler(.string(String(data: data, encoding: .utf8) ?? ""))
        }
        
        pipe.fileHandleForReading.readInBackgroundAndNotify()
        task.launch()
    }
    
}

// example: let symbol = shell.outputOf(commandName: "atos", arguments: ["-arch", "arm64", "-o", fullPath, "-l", startAddress, address])


// https://stackoverflow.com/a/32240064/1364404

public extension String {
    @discardableResult func runAsCommand() -> String {
        let pipe = Pipe()
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", String(format:"%@", self)]
        task.standardOutput = pipe
        let file = pipe.fileHandleForReading
        task.launch()
        if let result = NSString(data: file.readDataToEndOfFile(), encoding: String.Encoding.utf8.rawValue) {
            return result as String
        }
        else {
            return "--- Error running command - Unable to initialize string from file data ---"
        }
    }
    
    func emailAsBody(subject: String, emailTo: String) {
        let command = "echo \"\(self)\" | mail -s \"\(subject)\" \(emailTo)"
        command.runAsCommand()
    }
}

/* example:
 let command = "echo This is the email message | mail -s \"This is the subject\" eric.schramm@gmail.com"
 let returnString = command.runAsCommand()
 */
#endif
