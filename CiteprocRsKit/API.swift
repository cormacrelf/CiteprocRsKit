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

public class CRDriver {
    private let raw: OpaquePointer
    private let fetch_ctx: FFIUserData<FetchContext>

    private init(raw: OpaquePointer, fetch_ctx: FetchContext) {
        self.raw = raw
        self.fetch_ctx = FFIUserData(fetch_ctx)
    }
    
    public init(style: String,
                localeCallback: @escaping (String) -> String? = { _ in nil },
                outputFormat: CROutputFormat = .html) throws {

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
            if let err = CRBindingsError.from_last_error() {
                throw err
            } else {
                throw CRBindingsError(CRErrorCode.nullPointer, "null pointer returned from citeproc_rs_driver_new, but no error present")
            }
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

    deinit {
        citeproc_rs_driver_free(driver: self.raw)
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
