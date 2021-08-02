//
//  Thing.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 24/3/21.
//

import CiteprocRs
import CoreText
import Foundation

public typealias CROutputFormat = CiteprocRs.CROutputFormat
public typealias CRErrorCode = CiteprocRs.CRErrorCode
public typealias CRClusterId = CiteprocRs.CRClusterId
public typealias CRClusterPosition = CiteprocRs.CRClusterPosition

public class CRDriver {
    internal let raw: OpaquePointer
    private let fetch_ctx: FFIUserData<FetchContext>

    private init(raw: OpaquePointer, fetch_ctx: FetchContext) {
        self.raw = raw
        self.fetch_ctx = FFIUserData(fetch_ctx)
    }
    
    public init(style: String,
                localeCallback: @escaping (String) -> String? = { _ in nil },
                outputFormat: CROutputFormat = CROutputFormat.html) throws {

        let fetch_context = FFIUserData(FetchContext(locale_callback: localeCallback))
        guard let data = style.data(using: .utf8, allowLossyConversion: false) else {
            // this would be very dramatic, you would somehow have to create a Swift string that
            // is not able to be represented as utf8. So this will never happen.
            throw CRBindingsError(CRErrorCode.utf8, "unable to convert input style to utf8")
        }
        citeproc_rs_clear_last_error()
        let maybeRawPointer: OpaquePointer? = data.withCharPointer({ style, style_len in
            let options = CiteprocRs.CRInitOptions(
                style: style,
                style_len: style_len,
                locale_fetch_context: fetch_context.borrow(),
                locale_fetch_callback: localeFetchCallback,
                format: outputFormat,
                buffer_ops: BufferOps
            )
            // the default return value is implicitly unwrapped
            // Optional OpaquePointers are nil if they're NULL
            // so this `as OpaquePointer?` lets us explicitly check for NULL.
            return citeproc_rs_driver_new(init: options) as OpaquePointer?
        })
        guard let raw = maybeRawPointer else {
            throw CRBindingsError.last_or_default(
                default: CRBindingsError(CRErrorCode.nullPointer,
                                         "null pointer returned from citeproc_rs_driver_new, but no error present"))
        }
        self.raw = raw
        self.fetch_ctx = fetch_context  // no longer mutable outside callback, but also don't read it. leave it alone!
    }

    public func previewReference(_ reference: Any) throws -> String {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        var buffer = UTF8Buffer()
        let code = ref_json.withCharPointer({ buf, bufLen in
            Swift.withUnsafeMutablePointer(
                to: &buffer,
                { user_buffer in
                    citeproc_rs_driver_preview_reference(
                        driver: self.raw, ref_json: buf, ref_json_len: bufLen,
                        user_buf: user_buffer)
                })
        })
        try CRBindingsError.maybe_throw(returned: code)
        return buffer.to_string()
    }

    public func insertReference(_ reference: Any) throws {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        let code = ref_json.withCharPointer({ buf, buf_len in
            citeproc_rs_driver_insert_reference(
                driver: self.raw, ref_json: buf, ref_json_len: buf_len)
        })
        try CRBindingsError.maybe_throw(returned: code)
    }
    
    public func internClusterId(_ stringId: String) throws -> CRClusterId {
        // copy :(
        var stringId = stringId
        return try stringId.withUTF8Rust({ sid, sid_len in
            let id = citeproc_rs_driver_intern_string(driver: self.raw, str: sid, str_len: sid_len)
            if id == -1 {
                throw CRBindingsError.last_or_default()
            }
            return CRClusterId.init(id)
        })
    }
    
    public func newCluster(_ stringId: String) throws -> CRClusterHandle {
        let id = try self.internClusterId(stringId)
        return try self.newCluster(id)
    }
    
    public func newCluster(_ id: CRClusterId) throws -> CRClusterHandle {
        let maybe = citeproc_rs_cluster_new(id: id)
        guard let ptr = maybe else {
            throw CRBindingsError.last_or_default()
        }
        return CRClusterHandle(pointer: ptr, id: id)
    }
    
    public func insertCluster(_ cluster: CRClusterHandle) throws -> CRClusterId {
        let code = CiteprocRs.citeproc_rs_driver_insert_cluster(driver: self.raw, cluster: cluster.clusterRaw)
        try CRBindingsError.maybe_throw(returned: code)
        return cluster.id
    }
    
    public func formatCluster(clusterId: CRClusterId) throws -> String {
        var buffer = UTF8Buffer.init()
        let code = CiteprocRs.citeproc_rs_driver_format_cluster(driver: self.raw, cluster_id: clusterId, user_buf: &buffer)
        try CRBindingsError.maybe_throw(returned: code)
        return buffer.to_string()
    }
    
    public func setClusterOrder(positions: [CRClusterPosition]) throws {
        let len = UInt(positions.count)
        let code = CiteprocRs.citeproc_rs_driver_set_cluster_order(driver: self.raw, positions: positions, positions_len: len)
        try CRBindingsError.maybe_throw(returned: code)
    }
    
    public func formatBibliography() throws -> String {
        var buffer = UTF8Buffer.init()
        let code = CiteprocRs.citeproc_rs_driver_format_bibliography(driver: self.raw, user_buf: &buffer)
        try CRBindingsError.maybe_throw(returned: code)
        return buffer.to_string()
    }

    deinit {
        citeproc_rs_driver_free(driver: self.raw)
    }
}

private class CRCiteLifetime {
    internal init(clusterPointer: OpaquePointer) {
        self.clusterRaw = clusterPointer
    }
    
    let clusterRaw: OpaquePointer
}

public struct CRCiteHandle {
    fileprivate let index: UInt
    fileprivate weak var lifetime: CRCiteLifetime?
}

public class CRClusterHandle {
    internal init(pointer: OpaquePointer, id: CRClusterId) {
        self.id = id
        self.clusterRaw = pointer
        self.citeLifetime = CRCiteLifetime(clusterPointer: pointer)
    }
    
    var id: CRClusterId
    let clusterRaw: OpaquePointer
    fileprivate var citeLifetime: CRCiteLifetime
    
    deinit {
        citeproc_rs_cluster_free(cluster: self.clusterRaw)
    }
}

extension CRClusterHandle {
    /// Returns the cite number in this cluster.
    public func newCite(refId: String) throws -> CRCiteHandle {
        var refId = refId
        return try refId.withUTF8Rust({ ref, refLen in
            let idx = citeproc_rs_cluster_cite_new(cluster: self.clusterRaw, ref_id: ref, ref_id_len: refLen)
            if idx == -1 {
                throw CRBindingsError.last_or_default()
            }
            let index = UInt(idx)
            return CRCiteHandle(index: index, lifetime: self.citeLifetime)
        })
    }
    
    public func reset(newId: CRClusterId) throws {
        // invalidate all the cite handles
        self.citeLifetime = CRCiteLifetime(clusterPointer: self.clusterRaw)
        self.id = newId
        let code = citeproc_rs_cluster_reset(cluster: self.clusterRaw, new_id: newId)
        try CRBindingsError.maybe_throw(returned: code)
    }
}

extension CRCiteHandle {
    public func setPrefix(_ prefix: String) throws {
        var prefix = prefix
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRBindingsError.init(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try prefix.withUTF8Rust({ pfx, pfxLen in
            let code = citeproc_rs_cluster_cite_set_prefix(cluster: clusterRaw, cite_index: self.index, prefix: pfx, prefix_len: pfxLen)
            try CRBindingsError.maybe_throw(returned: code)
        })
    }
    
    public func setSuffix(_ suffix: String) throws {
        var suffix = suffix
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRBindingsError.init(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try suffix.withUTF8Rust({ sfx, sfxLen in
            let code = citeproc_rs_cluster_cite_set_suffix(cluster: clusterRaw, cite_index: self.index, suffix: sfx, suffix_len: sfxLen)
            try CRBindingsError.maybe_throw(returned: code)
        })
    }
    
    public func setRefId(refId: String) throws {
        var refId = refId
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRBindingsError.init(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try refId.withUTF8Rust({ r, rLen in
            let code = citeproc_rs_cluster_cite_set_ref(cluster: clusterRaw, cite_index: self.index, ref_id: r, ref_id_len: rLen)
            try CRBindingsError.maybe_throw(returned: code)
        })
    }
}

extension Data {
    func withCharPointer<T>(_ f: (UnsafePointer<Int8>, UInt) throws -> T) rethrows -> T {
        return try self.withUnsafeBytes({ bytes in
            let baseAddress: UnsafePointer<Int8> = bytes.baseAddress!.assumingMemoryBound(
                to: Int8.self)
            // why is unsafebufferpointer.count a signed integer????????????????
            let count: UInt = UInt(bytes.count)
            return try f(baseAddress, count)
        })
    }
}

extension String {
    internal mutating func withUTF8Rust<T>(_ f: (UnsafePointer<Int8>, UInt) throws -> T) rethrows -> T {
        // withUTF8 is mutating, it may put the string in contiguous storage temporarily or permanently, reallocate, etc.
        return try self.withUTF8({ bytes in
            let len = bytes.count
            if let baseAddress = bytes.baseAddress {
                return try baseAddress.withMemoryRebound(to: Int8.self, capacity: len, { pointer in
                    return try f(pointer, UInt(len))
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

