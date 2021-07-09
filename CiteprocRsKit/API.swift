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
            CiteprocRs.citeproc_rs_write_locale_slot(slot: slot, locale_xml: baseAddress, locale_xml_len: count)
        })
    }
}

public enum BindingsError: Error {
    case invalidUtf8
    case internalError(String)
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
        let maybe_raw: OpaquePointer? =  with_data_as_char_ptr(data, { style, style_len in
            let options = CiteprocRsInitOptions(
                style: style,
                style_len: style_len,
                locale_fetch_context: ctx_raw,
                locale_fetch_callback: locale_fetch_callback,
                format: options.output_format
            )
            return citeproc_rs_processor_new(init: options)
        })
        guard let raw = maybe_raw else {
            throw BindingsError.internalError("Null driver returned from citeproc_rs")
        }
        self.raw = raw
        self.fetch_ctx = UnsafePointer(ctx) // no longer mutable outside callback, but also don't read it
    }
    
    public func one_ref_citation(_ reference: Any) throws -> String? {
        let ref_json: Data = try JSONSerialization.data(withJSONObject: reference)
        guard let ptr = with_data_as_char_ptr(ref_json, { buf, buf_len in
            return citeproc_rs_processor_format_one(processor: self.raw, ref_bytes: buf, ref_bytes_len: buf_len)
        }) else {
            return nil
        }
        return string_from_rust_cstring(ptr)
    }
    
    deinit {
        self.fetch_ctx.deallocate()
        citeproc_rs_processor_free(processor: self.raw)
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

internal func string_from_rust_cstring(_ ptr: UnsafeMutablePointer<CChar>) -> String {
    let s = String.init(cString: ptr)
    CiteprocRs.citeproc_rs_string_free(ptr: ptr)
    return s
}
