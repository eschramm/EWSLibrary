//
//  File.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 7/18/24.
//

@preconcurrency import Darwin

var machTaskSelf: mach_port_t {
    mach_task_self_
}

