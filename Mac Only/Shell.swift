//
//  Shell.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/23/18.
//  Copyright © 2018 eware. All rights reserved.
//

import Foundation

//https://gist.github.com/andreacipriani/8c3af3719da31c8fae2cdfa8c21e17ba

public final class Shell
{
    func outputOf(commandName: String, arguments: [String] = []) -> String? {
        return bash(commandName: commandName, arguments:arguments)
    }
    
    // MARK: private
    
    private func bash(commandName: String, arguments: [String]) -> String? {
        guard var whichPathForCommand = executeShell(command: "/bin/bash" , arguments:[ "-l", "-c", "which \(commandName)" ]) else {
            return "\(commandName) not found"
        }
        whichPathForCommand = whichPathForCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        return executeShell(command: whichPathForCommand, arguments: arguments)
    }
    
    private func executeShell(command: String, arguments: [String] = []) -> String? {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String? = String(data: data, encoding: String.Encoding.utf8)
        
        return output
    }
    
}

//example: let symbol = shell.outputOf(commandName: "atos", arguments: ["-arch", "arm64", "-o", fullPath, "-l", startAddress, address])
