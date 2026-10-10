//
//  File.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 7/18/24.
//

#if canImport(Darwin)
@preconcurrency import Darwin

var machTaskSelf: mach_port_t {
    mach_task_self_
}
#endif
