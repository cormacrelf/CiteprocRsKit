//
//  Thing.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 24/3/21.
//

import CiteprocRs
import CoreText
import Foundation

/// Enum, format to write output in: .html, .rtf, .plain
///
/// The enum variants are not viewable in documentation due to this being a re-export from a C header.
public typealias CROutputFormat = CiteprocRs.CROutputFormat

/// Enum, error code directly from citeproc-rs' ffi layer (.nullPointer, .caughtPanic, .serdeJson, etc).
///
/// The enum variants are not viewable in documentation due to this being a re-export from a C header.
public typealias CRErrorCode = CiteprocRs.CRErrorCode

/// An integer (`UInt32`) representation of a cluster ID.
public typealias CRClusterId = CiteprocRs.CRClusterId

// Lifecycle

/// The central API for interacting with CiteprocRsKit.
public class CRDriver {
    internal let raw: OpaquePointer
    private let fetch_ctx: FFIUserData<FetchContext>
    internal var buffer: UTF8Buffer
    private let outputFormat: CROutputFormat

    private init(raw: OpaquePointer, fetch_ctx: FFIUserData<FetchContext>, outputFormat: CROutputFormat) {
        self.raw = raw
        // no longer mutable outside callback, but also don't read it. leave it alone!
        self.fetch_ctx = fetch_ctx
        self.buffer = UTF8Buffer()
        self.outputFormat = outputFormat
    }
    
    /// Create a driver for an XML style.
    ///
    /// You provide:
    /// - A valid XML style
    /// - A way for the driver to ask for XML locales by language ID (e.g. `"en-GB"`),
    ///   where the default results in every locale being indistinguishable from `en-US`.
    /// - And an output format of your choice, default `.html`.
    public convenience init(style: String,
                            localeCallback: @escaping (_ langId: String) -> String? = { _ in nil },
                outputFormat: CROutputFormat = CROutputFormat.html) throws {

        let fetch_context = FFIUserData(FetchContext(locale_callback: localeCallback))
        guard let data = style.data(using: .utf8, allowLossyConversion: false) else {
            // this would be very dramatic, you would somehow have to create a Swift string that
            // is not able to be represented as utf8. So this will never happen.
            throw CRError(CRErrorCode.utf8, "unable to convert input style to utf8")
        }
        citeproc_rs_last_error_clear();
        let maybeRawPointer: OpaquePointer? = data.withCharPointerLen({ style, style_len in
            let options = CiteprocRs.CRInitOptions(
                style: style,
                style_len: style_len,
                locale_fetch_context: fetch_context.borrow(),
                locale_fetch_callback: localeFetchCallback,
                format: outputFormat,
                buffer_ops: UTF8Buffer.bufferOps
            )
            // the default return value is implicitly unwrapped
            // Optional OpaquePointers are nil if they're NULL
            // so this `as OpaquePointer?` lets us explicitly check for NULL.
            return citeproc_rs_driver_new(init: options) as OpaquePointer?
        })
        guard let raw = maybeRawPointer else {
            throw CRError.last_or_default(
                default: CRError(CRErrorCode.nullPointer,
                                         "null pointer returned from citeproc_rs_driver_new, but no error present"))
        }
        self.init(raw: raw, fetch_ctx: fetch_context, outputFormat: outputFormat)
    }
    
    deinit {
        citeproc_rs_driver_free(driver: self.raw)
    }
}

extension CRDriver {
    
    /// Shows what a reference would look like if rendered in a bibliography. The reference must have an `"id"` field but it will not be used.
    public func previewReference(_ reference: Any, format: CROutputFormat? = nil) throws -> String {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        let code = ref_json.withCharPointerLen({ buf, bufLen in
            citeproc_rs_driver_preview_reference(
                driver: self.raw,
                ref_json: buf, ref_json_len: bufLen,
                format: format ?? self.outputFormat,
                user_buf: &self.buffer)
        })
        try CRError.maybe_throw(returned: code)
        return buffer.takeString()
    }

    /// Add a Reference to the Driver.
    public func insertReference(_ reference: Any) throws {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        let code = ref_json.withCharPointerLen({ buf, buf_len in
            citeproc_rs_driver_insert_reference(
                driver: self.raw, ref_json: buf, ref_json_len: buf_len)
        })
        try CRError.maybe_throw(returned: code)
    }
    
    /// Concatenates all the bibliography entries into one string.
    public func formatBibliography() throws -> String {
        let code = CiteprocRs.citeproc_rs_driver_format_bibliography(driver: self.raw, user_buf: &self.buffer)
        try CRError.maybe_throw(returned: code)
        return buffer.takeString()
    }
    
    /// Formats a single citation cluster.
    public func formatCluster(clusterId: CRClusterId) throws -> String {
        let code = CiteprocRs.citeproc_rs_driver_format_cluster(driver: self.raw, cluster_id: clusterId, user_buf: &self.buffer)
        try CRError.maybe_throw(returned: code)
        return buffer.takeString()
    }
    
    /// Tell the driver how your document is structured.
    public func setClusterOrder(positions: [CRClusterPosition]) throws {
        let code: CRErrorCode = positions.withUnsafeBufferPointer({ pointer in
            return pointer.withMemoryRebound(to: RawPosition.self, { transmutedPointer in
                let base = transmutedPointer.baseAddress
                let len = UInt(transmutedPointer.count)
                return CiteprocRs.citeproc_rs_driver_set_cluster_order(driver: self.raw, positions: base, positions_len: len)
            })
        })
        try CRError.maybe_throw(returned: code)
    }
}
