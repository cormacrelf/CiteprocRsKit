//
//  Buffer.swift
//  CiteprocRsKit
//
// An implementation of the CiteprocRs.BufferOps (C) protocol
// Its primary benefit is managing the string copying between Swift<->Rust with Swift's own
// memory management (ARC) instead of manually freeing Rust CStrings.
//
//  Created by Cormac Relf on 28/7/21.
//

import CiteprocRs
import Foundation

/// This is a buffer that can eventually be decoded into a String via output().
/// It implements the CiteprocRsBufferOps methods.
internal struct UTF8Buffer {
    var data: Data = .init()
    func to_string() -> String {
        String(decoding: self.data, as: UTF8.self)
    }

    internal mutating func write_bytes(_ buf: UnsafePointer<UInt8>, _ buf_len: UInt) {
        let buffer_ptr = UnsafeBufferPointer.init(start: buf, count: Int(buf_len))
        self.data.append(buffer_ptr)
    }

    internal mutating func clear() {
        self.data.removeAll(keepingCapacity: true)
    }
}

/// Wrapper for UTF8Buffer.write_bytes for the CiteprocRsBufferOps.write interface
func buffer_write_cb(
    user_data: UnsafeMutableRawPointer?, buf: UnsafePointer<UInt8>?, buf_len: UInt
) {
    if let writer = UnsafeMutablePointer<UTF8Buffer>.init(OpaquePointer(user_data)) {
        writer.pointee.write_bytes(buf!, buf_len)
    }
}

/// Wrapper for UTF8Buffer.clear for the CiteprocRsBufferOps.clear interface
func buffer_clear_cb(user_data: UnsafeMutableRawPointer?) {
    if let writer = UnsafeMutablePointer<UTF8Buffer>.init(OpaquePointer(user_data)) {
        writer.pointee.clear()
    }
}

let BufferOps = CRBufferOps(
    write: buffer_write_cb,
    clear: buffer_clear_cb
)
