//
//  Thing.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 24/3/21.
//

import Foundation
import CoreText
import CiteprocRs

public typealias OutputFormat = CiteprocRs.CiteprocRsOutputFormat

public struct InitOptions {
    public init(style: String, locale_callback: @escaping (String) -> String?, output_format: OutputFormat = .html) {
        self.style = style
        self.locale_callback = locale_callback
        self.output_format = output_format
    }
    
    public var style: String
    public var locale_callback: (String) -> String?
    public var output_format: OutputFormat = .html
}

struct FetchContext {
    let locale_callback: (String) -> String?
}

func locale_fetch_callback(ctx_raw: UnsafeMutableRawPointer?, slot: OpaquePointer?, lang_cstr: UnsafePointer<Int8>?) {
    guard let lang_ptr = lang_cstr else {
        return
    }
    let lang = String.init(cString: lang_ptr)
    if let locale = ctx_raw?.assumingMemoryBound(to: FetchContext.self).pointee.locale_callback(lang) {
        let data: Data? = locale.data(using: .utf8, allowLossyConversion: false)
        data?.withUnsafeBytes({ bytes in
            // why is unsafebufferpointer.count a signed integer????????????????
            let count = UInt(bytes.count)
            let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: Int8.self)
            CiteprocRs.citeproc_rs_locale_slot_write(slot: slot, locale_xml: baseAddress, locale_xml_len: count)
        })
    }
}

public enum BindingsError: Error {
    case invalidUtf8
    case internalError(CiteprocRsErrorCode, String)
    
    internal static func error_display_text() -> String {
        let len = CiteprocRs.citeproc_rs_last_error_length();
        if len == 0 {
            return ""
        }
        var buffer = [UInt8].init(repeating: 0, count: Int(len));
        let bytes_written = buffer.withUnsafeMutableBytes({ raw_buf_ptr -> Int in
            let baseAddress: UnsafeMutablePointer<CChar> = raw_buf_ptr.baseAddress!.assumingMemoryBound(to: Int8.self)
            return CiteprocRs.citeproc_rs_error_message_utf8(buf: baseAddress, length: len)
        })
        if bytes_written == -1 {
            return ""
        }
        let written_slice = buffer.prefix(bytes_written)
        return String(decoding: written_slice, as: UTF8.self)
    }
    
    internal init(internal_error: CiteprocRsErrorCode, api_name: String) {
        switch internal_error {
        case CiteprocRsErrorCode.none:
            self = BindingsError.internalError(internal_error, "no error, but null value returned from \(api_name)")
        case CiteprocRsErrorCode.caughtPanic: fallthrough
        case CiteprocRsErrorCode.poisoned: fallthrough
        case CiteprocRsErrorCode.utf8: fallthrough
        case CiteprocRsErrorCode.reordering: fallthrough
        case CiteprocRsErrorCode.nullPointer: fallthrough
        @unknown default:
            let e_str = BindingsError.error_display_text();
            self = BindingsError.internalError(internal_error, e_str)
        }
    }
    
    internal static func from_last_error(api_name: String = "") -> Self {
        let e = CiteprocRs.citeproc_rs_last_error_code()
        return BindingsError(internal_error: e, api_name: api_name)
    }
}

public class CiteprocRsDriver {
    internal init(raw: OpaquePointer, fetch_ctx: UnsafePointer<FetchContext>) {
        self.raw = raw
        self.fetch_ctx = fetch_ctx
    }
    
    private let raw: OpaquePointer
    private let fetch_ctx: UnsafePointer<FetchContext>
    
    public init(_ options: InitOptions) throws {
        let ctx: UnsafeMutablePointer<FetchContext> = UnsafeMutablePointer.allocate(capacity: 1)
        ctx.initialize(to: FetchContext(locale_callback: options.locale_callback))
        let ctx_raw: UnsafeMutableRawPointer! = UnsafeMutableRawPointer(ctx)
        guard let data = options.style.data(using: .utf8, allowLossyConversion: false) else {
            throw BindingsError.invalidUtf8
        }
        citeproc_rs_clear_last_error();
        let maybe_raw: OpaquePointer? =  with_data_as_char_ptr(data, { style, style_len in
            let options = CiteprocRsInitOptions(
                style: style,
                style_len: style_len,
                locale_fetch_context: ctx_raw,
                locale_fetch_callback: locale_fetch_callback,
                format: options.output_format
            )
            return citeproc_rs_driver_new(init: options)
        })
        guard let raw = maybe_raw else {
            throw BindingsError.from_last_error(api_name: "citeproc_rs_driver_new");
        }
        self.raw = raw
        self.fetch_ctx = UnsafePointer(ctx) // no longer mutable outside callback, but also don't read it
    }
    
    public func one_ref_citation(_ reference: Any) throws -> String? {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        guard let ptr = with_data_as_char_ptr(ref_json, { buf, buf_len in
            return citeproc_rs_driver_format_one(driver: self.raw, ref_bytes: buf, ref_bytes_len: buf_len)
        }) else {
            return nil
        }
        return try string_from_rust_cstring(ptr)
    }
    
    deinit {
        self.fetch_ctx.deallocate()
        citeproc_rs_driver_free(driver: self.raw)
    }
}

internal func with_data_as_char_ptr<T>(_ data: Data, _ f: (UnsafePointer<Int8>, UInt) -> T) -> T {
    return data.withUnsafeBytes({ bytes in
        let baseAddress: UnsafePointer<Int8> = bytes.baseAddress!.assumingMemoryBound(to: Int8.self)
        // why is unsafebufferpointer.count a signed integer????????????????
        let count: UInt = UInt(bytes.count)
        return f(baseAddress, count)
    })
}

internal func string_from_rust_cstring(_ ptr: UnsafeMutablePointer<CChar>) throws -> String {
    guard let s = String(cString: ptr, encoding: .utf8) else {
        throw BindingsError.invalidUtf8
    }
    CiteprocRs.citeproc_rs_string_free(ptr: ptr)
    return s
}
