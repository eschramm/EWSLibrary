//
//  Data.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 10/11/25.
//

import Foundation

public enum UUIDError: Error {
    case wrongNumberOfBytesShouldBe16(Int)
}

public extension UUID {
    
    init(data: Data) throws {
        if data.count == MemoryLayout<uuid_t>.size {
            // Create a uuid_t array from Data
            var uuidBytes = [UInt8](repeating: 0, count: 16)
            data.copyBytes(to: &uuidBytes, count: 16)
            
            // Now uuidBytes contains the 16-byte representation of the UUID
            let uuid: uuid_t = (
                uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
            )
            self.init(uuid: uuid)
        } else {
            throw UUIDError.wrongNumberOfBytesShouldBe16(data.count)
        }
    }
    
    var data: Data {
        return withUnsafeBytes(of: uuid) { Data($0) }
    }
}

public extension Data {
    func toHexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    func descriptionEWS() -> String {
        if let stringRepresentation = String(data: self, encoding: .utf8) {
            return stringRepresentation
        } else if self.count == 16 {
            return (try? UUID(data: self).uuidString) ?? self.count.formatted(.byteCount(style: .binary))
        } else {
            print(self.count)
            return self.count.formatted(.byteCount(style: .binary))
        }
    }
}
