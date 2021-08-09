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
    mutating func takeString() -> String {
        let str = String(decoding: self.data, as: UTF8.self)
        self.data.removeAll(keepingCapacity: true)
        return str
    }
    
    func intoString() -> String {
        return String(decoding: self.data, as: UTF8.self)
    }

    internal mutating func writeBytes(_ buf: UnsafePointer<UInt8>, _ buf_len: UInt) {
        let buffer_ptr = UnsafeBufferPointer(start: buf, count: Int(buf_len))
        self.data.append(buffer_ptr)
    }

    internal mutating func clear() {
        self.data.removeAll(keepingCapacity: true)
    }
}

/// Wrapper for UTF8Buffer.writeBytes for the CiteprocRsBufferOps.write interface
fileprivate func bufferWriteCallback(
    userData: UnsafeMutableRawPointer?, buf: UnsafePointer<UInt8>?, bufLen: UInt
) {
    if let writer = UnsafeMutablePointer<UTF8Buffer>(OpaquePointer(userData)) {
        writer.pointee.writeBytes(buf!, bufLen)
    }
}

/// Wrapper for UTF8Buffer.clear for the CiteprocRsBufferOps.clear interface
fileprivate func bufferClearCallback(userData: UnsafeMutableRawPointer?) {
    if let writer = UnsafeMutablePointer<UTF8Buffer>(OpaquePointer(userData)) {
        writer.pointee.clear()
    }
}

extension UTF8Buffer {
    static let bufferOps = CRBufferOps(
        write: bufferWriteCallback,
        clear: bufferClearCallback
    )
}

// Now some extensions to make passing data _to_ FFI easier.

extension Data {
    func withCharPointerLen<T>(_ f: (UnsafePointer<Int8>, UInt) throws -> T) rethrows -> T {
        return try self.withUnsafeBytes({ bytes in
            let len = UInt(bytes.count)
            if let baseAddress = bytes.baseAddress {
                let baseAddress = baseAddress.assumingMemoryBound(to: Int8.self)
                return try f(baseAddress, len)
            } else {
                // it's actually quite annoying to get a null pointer in swift.
                // we'll just give it a valid pointer with zero for the length.
                // then the body function f doesn't need to know it's potentially "null"
                var zero: Int8 = 0
                return try f(&zero, 0)
            }
        })
    }
}

extension String {
    /// A wrapper for String.withUTF8 that is compatible with *const c_char / usize on the rust side.
    internal mutating func withUTF8Rust<T>(_ f: (UnsafePointer<Int8>, UInt) throws -> T) rethrows -> T {
        // withUTF8 is mutating, it may put the string in contiguous storage temporarily or permanently, reallocate, etc.
        return try self.withUTF8({ bytes in
            let len = bytes.count
            if let baseAddress = bytes.baseAddress {
                return try baseAddress.withMemoryRebound(to: Int8.self, capacity: len, { pointer in
                    return try f(pointer, UInt(bytes.count))
                })
            } else {
                // it's actually quite annoying to get a null pointer in swift.
                // we'll just give it a valid pointer with zero for the length.
                // then the body function f doesn't need to know it's potentially "null"
                var zero: Int8 = 0
                return try f(&zero, 0)
            }
        })
    }
}

