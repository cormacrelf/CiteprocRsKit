//
//  Cluster.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 3/8/21.
//

import Foundation
import CiteprocRs

internal typealias RawPosition = CiteprocRs.CRClusterPosition;

// These are transparent structs. We can safely "transmute" pointers to arrays of it.
// As noted in [SE-0260](https://github.com/apple/swift-evolution/blob/main/proposals/0260-library-evolution.md):
//
// > The run-time memory layout of a struct with a single field is always identical
// > to the layout of the instance property on its own, whether the struct is
// > declared @frozen or not. This has been true since Swift 1. (This does not
// > extend to the calling convention, however. If the struct is not frozen, it will
// > be passed indirectly even if its single field is frozen and thus can be passed
// > directly)

/// A cluster position for use in ``CRDriver/setClusterOrder(positions:)``
public struct CRClusterPosition {
    // crucial: only one field
    internal let raw: RawPosition
    
    /// An initialiser for a real cluster that's either in a footnote (a number) or in-text (nil)
    public init(id: CRClusterId, noteNumber: UInt32? = nil) {
        self.raw = RawPosition.init(is_preview_marker: false, id: id, is_note: noteNumber != nil, note_number: noteNumber ?? 0)
    }
}


/// A cluster position for use in a future `previewCitationCluster`-esque API.
internal struct CRClusterPreviewPosition {
    // crucial: only one field
    internal let raw: RawPosition

    private init(preview: (), noteNumber: UInt32? = nil) {
        self.raw = RawPosition.init(is_preview_marker: true, id: 0, is_note: noteNumber != nil, note_number: noteNumber ?? 0)
    }
    
    /// An initialiser for a real cluster that's either in a footnote (a number) or in-text (nil)
    public init(id: CRClusterId, noteNumber: UInt32? = nil) {
        self.raw = RawPosition.init(is_preview_marker: false, id: id, is_note: noteNumber != nil, note_number: noteNumber ?? 0)
    }
    
    /// An initialiser for a preview cluster. Only for use marking the preview placeholder's spot in a preview operation.
    public static func preview(noteNumber: UInt32? = nil) -> Self {
        .init(preview: (), noteNumber: noteNumber)
    }
}

/// A structure for describing a cluster to submit to citeproc-rs.
/// * A cluster handle is created via `CRDriver.clusterHandle(id:)`
/// * You then append a bunch of `CRCite`s.
/// * The completed handle is submitted to `CRDriver.insertCluster(_ cluster:)`
/// * The handle can then be reused to submit more clusters, by resetting it via `CRClusterHandle.reset(newId:)`
public class CRClusterHandle {
    internal init(driverRef: CRDriver, pointer: OpaquePointer, id: CRClusterId) {
        self.clusterRaw = pointer
        self.id = id
        self.driverRef = driverRef
    }
    
    public fileprivate(set) var id: CRClusterId
    fileprivate let clusterRaw: OpaquePointer
    weak var driverRef: CRDriver?
    
    /// Create a cluster handle, either uninitialised or initialised with a specific cluster ID.
    ///
    /// To initialise a handle which doesn't yet have an ID, use ``CRClusterHandle/reset(newId:)``
    internal convenience init(driverRef: CRDriver, id: CRClusterId) throws {
        // we'll give it a value of zero if there's no id yet.
        let ptr = citeproc_rs_cluster_new(id: id)
        if ptr == nil {
            throw CRError.from_last_error() ?? CRError(.nullPointer, "Null pointer returned from citeproc_rs_cluster_new, probably OOM")
        }
        self.init(driverRef: driverRef, pointer: ptr!, id: id)
    }
    
    deinit {
        citeproc_rs_cluster_free(cluster: self.clusterRaw)
    }
    
    /// CRClusterHandle is reusable. This clears the storage but keeps the allocations used for transferring data over FFI.
    private func _reset(_ newId: CRClusterId) throws {
        self.id = newId
        let code = citeproc_rs_cluster_reset(cluster: self.clusterRaw, new_id: newId)
        try CRError.maybe_throw(returned: code)
    }

    /// CRClusterHandle is reusable. This clears the storage but keeps the allocations used for transferring data over FFI.
    public func reset(newId: CRClusterId) throws {
        try self._reset(newId)
    }
    
    /// CRClusterHandle is reusable. This clears the storage but keeps the allocations used for transferring data over FFI.
    public func reset(_ stringId: String) throws {
        guard let driver = self.driverRef else {
            throw CRError.init(.nullPointer, "Cannot intern a string in CRClusterHandle.reset if the associated driver has been deallocated")
        }
        let newId = try driver.internClusterId(stringId)
        try self._reset(newId)
    }
}

extension CRDriver {
    
    /// Obtain a cluster handle for a specific cluster ID.
    public func clusterHandle(_ id: CRClusterId) throws -> CRClusterHandle {
        return try CRClusterHandle(driverRef: self, id: id)
    }
    
    /// Obtain a cluster handle for an **interned string ID**.
    public func clusterHandle(_ stringId: String) throws -> CRClusterHandle {
        let id = try self.internClusterId(stringId)
        return try CRClusterHandle(driverRef: self, id: id)
    }
    
    /// Inserts a cluster whose ID is the one contained in the handle. This will overwrite any existing cluster with the same ID.
    public func insertCluster(_ cluster: CRClusterHandle) throws {
        let code = CiteprocRs.citeproc_rs_driver_insert_cluster(driver: self.raw, cluster: cluster.clusterRaw)
        try CRError.maybe_throw(returned: code)
    }
    
    /// Takes a string, and gives you a new ID to use in its place. The ID can be any number, so do not use in conjunction with explicitly constructed, numbered ``CRClusterId``s,
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
    
    /// Pick a nice cluster ID out of thin air, and return its integer and string forms. You can use this to generate permanent IDs to be stored in a document somewhere.
    public func randomClusterId() throws -> (CRClusterId, String) {
        let id = citeproc_rs_driver_random_cluster_id(driver: self.raw, user_buf: &self.buffer)
        if id < 0 {
            throw CRError.from_last_error() ?? CRError.init(CRErrorCode.none, "unknown error")
        }
        return (.init(UInt32(id)), self.buffer.takeString())
    }
    
}

extension CRClusterHandle {
    
    /// Returns a cite handle, which can be used to add information to the cite.
    /// The cite handle is invalidated if the CRClusterHandle is dropped or is reset, so discard any cites handles after doing either.
    private func newCite(refId: String) throws -> CRCiteHandle {
        var refId = refId
        return try refId.withUTF8Rust({ ref, refLen in
            let idx = citeproc_rs_cluster_cite_new(cluster: self.clusterRaw, ref_id: ref, ref_id_len: refLen)
            if idx == -1 {
                throw CRError.last_or_default()
            }
            let index = UInt(idx)
            return CRCiteHandle(index: index, clusterRaw: self.clusterRaw)
        })
    }
    
    public func append<S>(contentsOf cites: S) throws where S: Sequence, S.Element == CRCite {
        try cites.forEach({ cite in try self.append(cite)})
    }
    
    /// Append a new, simple cite to the cluster. No affixes or locator.
    public func append(refId: String) throws {
        let _ = try self.newCite(refId: refId)
    }
    
    /// Append a new cite to the cluster.
    public func append(_ cite: CRCite) throws {
        let handle = try self.newCite(refId: cite.refId)
        if let p = cite.prefix  { try handle.setPrefix(p) }
        if let s = cite.suffix  { try handle.setSuffix(s) }
        if let (l, t) = cite.locator { try handle.setLocator(l, locType: t) }
    }
}

fileprivate struct CRCiteHandle {
    fileprivate let index: UInt
    fileprivate var clusterRaw: OpaquePointer
}

extension CRCiteHandle {
    /// sets the cite prefix
    fileprivate func setPrefix(_ prefix: String) throws {
        var prefix = prefix
        try prefix.withUTF8Rust({ pfx, pfxLen in
            let code = citeproc_rs_cluster_cite_set_prefix(cluster: clusterRaw, cite_index: self.index, prefix: pfx, prefix_len: pfxLen)
            try CRError.maybe_throw(returned: code)
        })
    }
    
    /// sets the cite suffix
    fileprivate func setSuffix(_ suffix: String) throws {
        var suffix = suffix
        try suffix.withUTF8Rust({ sfx, sfxLen in
            let code = citeproc_rs_cluster_cite_set_suffix(cluster: clusterRaw, cite_index: self.index, suffix: sfx, suffix_len: sfxLen)
            try CRError.maybe_throw(returned: code)
        })
    }
    
    /// sets the reference pointed to by this cite
    fileprivate func setRefId(_ refId: String) throws {
        var refId = refId
        try refId.withUTF8Rust({ r, rLen in
            let code = citeproc_rs_cluster_cite_set_ref(cluster: clusterRaw, cite_index: self.index, ref_id: r, ref_id_len: rLen)
            try CRError.maybe_throw(returned: code)
        })
    }
    
    /// sets the locator for this cite
    fileprivate func setLocator(_ locator: String, locType: CRLocatorType) throws {
        var locator = locator
        try locator.withUTF8Rust({ r, rLen in
            let code = citeproc_rs_cluster_cite_set_locator(cluster: clusterRaw, cite_index: self.index, locator: r, locator_len: rLen, loc_type: locType)
            try CRError.maybe_throw(returned: code)
        })
    }
}

/// A convenient struct to hold details of a single cite within a cluster.
public struct CRCite: Equatable, Hashable {
    
    public init(refId: String, prefix: String? = nil, suffix: String? = nil, locator: (String, CRLocatorType)? = nil) {
        self.refId = refId
        self.prefix = prefix
        self.suffix = suffix
        self.locator = locator
    }
    
    var refId: String
    var prefix: String?
    var suffix: String?
    var locator: (String, CRLocatorType)?
    
    public static func == (lhs: CRCite, rhs: CRCite) -> Bool {
        lhs.refId == rhs.refId
        && lhs.prefix == rhs.prefix
        && lhs.suffix == rhs.suffix
        && lhs.locator?.0 == rhs.locator?.0
        && lhs.locator?.1 == rhs.locator?.1
    }
    
    public func hash(into: inout Hasher) {
        into.combine(refId)
        into.combine(prefix)
        into.combine(suffix)
        if let locator = locator {
            into.combine(locator.0)
            into.combine(locator.1)
        }
    }
}
