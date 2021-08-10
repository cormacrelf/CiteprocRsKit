//
//  Cluster.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 3/8/21.
//

import Foundation
import CiteprocRs

extension CRClusterPosition {
    /// An initialiser for a real cluster that's either in a footnote (a number) or in-text (nil)
    public init(id: CRClusterId, noteNumber: UInt32? = nil) {
        self.init(is_preview_marker: false, id: id, is_note: noteNumber != nil, note_number: noteNumber ?? 0)
    }
    /// An initialiser for a preview cluster. Only for use marking the preview placeholder's spot in a preview operation.
    public init(preview: (), noteNumber: UInt32? = nil) {
        self.init(is_preview_marker: true, id: 0, is_note: noteNumber != nil, note_number: noteNumber ?? 0)
    }
}

/// A structure for describing a cluster to submit to citeproc-rs.
/// * A cluster handle is created via `CRDriver.clusterHandle(id:)`
/// * You then edit it using its methods.
/// * The completed handle is submitted to `CRDriver.insertCluster(_ cluster:)`
/// * The handle can then be reused to submit more clusters, by resetting it via `CRClusterHandle.reset(newId:)`
public class CRClusterHandle {
    internal init(pointer: OpaquePointer, id: CRClusterId) {
        self.clusterRaw = pointer
        self.citeLifetime = CRCiteLifetime(clusterPointer: pointer)
        self.id = id
    }
    
    public fileprivate(set) var id: CRClusterId
    fileprivate let clusterRaw: OpaquePointer
    fileprivate var citeLifetime: CRCiteLifetime
    
    internal convenience init(id: CRClusterId) throws {
        let maybe = citeproc_rs_cluster_new(id: id) as OpaquePointer?
        guard let ptr = maybe else {
            throw CRError.last_or_default()
        }
        self.init(pointer: ptr, id: id)
    }
    
    deinit {
        citeproc_rs_cluster_free(cluster: self.clusterRaw)
    }
}

extension CRDriver {
    public func insertCluster(_ cluster: CRClusterHandle) throws -> CRClusterId {
        let code = CiteprocRs.citeproc_rs_driver_insert_cluster(driver: self.raw, cluster: cluster.clusterRaw)
        try CRError.maybe_throw(returned: code)
        return cluster.id
    }
    
    public func internClusterId(_ stringId: String) throws -> CRClusterId {
        // copy :( because withUTF8 mutates, especially often with small strings.
        var stringId = stringId
        return try stringId.withUTF8Rust({ sid, sid_len in
            let id = citeproc_rs_driver_intern_cluster_id(driver: self.raw, str: sid, str_len: sid_len)
            if id < 0 {
                // let code = CRErrorCode(rawValue: Int32(-id)) ?? CRErrorCode.none
                throw CRError.from_last_error() ?? CRError.init(CRErrorCode.none, "unknown error")
            }
            return CRClusterId(UInt32(id))
        })
    }
    
    public func clusterHandle(_ stringId: String) throws -> CRClusterHandle {
        let id = try self.internClusterId(stringId)
        return try self.clusterHandle(id)
    }
    
    
    public func clusterHandle(_ id: CRClusterId) throws -> CRClusterHandle {
        return try CRClusterHandle(id: id)
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

extension CRClusterHandle {
    /// Returns a cite handle, which can be used to add information to the cite.
    /// The cite handle is invalidated if the CRClusterHandle is dropped or is reset, so discard any cites handles after doing either.
    public func newCite(refId: String) throws -> CRCiteHandle {
        var refId = refId
        return try refId.withUTF8Rust({ ref, refLen in
            let idx = citeproc_rs_cluster_cite_new(cluster: self.clusterRaw, ref_id: ref, ref_id_len: refLen)
            if idx == -1 {
                throw CRError.last_or_default()
            }
            let index = UInt(idx)
            return CRCiteHandle(index: index, lifetime: self.citeLifetime)
        })
    }
    
    /// CRClusterHandle is reusable. This clears the storage but keeps the allocations used for transferring data over FFI.
    public func reset(newId: CRClusterId) throws {
        // invalidate all the cite handles
        self.citeLifetime = CRCiteLifetime(clusterPointer: self.clusterRaw)
        self.id = newId
        let code = citeproc_rs_cluster_reset(cluster: self.clusterRaw, new_id: newId)
        try CRError.maybe_throw(returned: code)
    }
}

extension CRCiteHandle {
    /// sets the cite prefix
    public func setPrefix(_ prefix: String) throws {
        var prefix = prefix
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRError(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try prefix.withUTF8Rust({ pfx, pfxLen in
            let code = citeproc_rs_cluster_cite_set_prefix(cluster: clusterRaw, cite_index: self.index, prefix: pfx, prefix_len: pfxLen)
            try CRError.maybe_throw(returned: code)
        })
    }
    
    /// sets the cite suffix
    public func setSuffix(_ suffix: String) throws {
        var suffix = suffix
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRError(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try suffix.withUTF8Rust({ sfx, sfxLen in
            let code = citeproc_rs_cluster_cite_set_suffix(cluster: clusterRaw, cite_index: self.index, suffix: sfx, suffix_len: sfxLen)
            try CRError.maybe_throw(returned: code)
        })
    }
    
    /// sets the reference pointed to by this cite
    public func setRefId(_ refId: String) throws {
        var refId = refId
        guard let clusterRaw = self.lifetime?.clusterRaw else {
            throw CRError(CRErrorCode.nullPointer, "attempted to use cite handle after cluster had been cleared")
        }
        try refId.withUTF8Rust({ r, rLen in
            let code = citeproc_rs_cluster_cite_set_ref(cluster: clusterRaw, cite_index: self.index, ref_id: r, ref_id_len: rLen)
            try CRError.maybe_throw(returned: code)
        })
    }
}
