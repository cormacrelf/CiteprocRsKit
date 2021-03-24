//
//  Thing.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 24/3/21.
//

import Foundation
import CoreText
import CiteprocRs

public struct InitOptions {
    public let style: String
    public let locale_callback: (String) -> String?
}

struct FetchContext {
    let locale_callback: (String) -> String?
}

func locale_fetch_callback(ctx_raw: UnsafeMutableRawPointer?, slot: OpaquePointer?, lang_cstr: UnsafePointer<Int8>?) {
    print("hi from doit")
    if let locale = ctx_raw?.assumingMemoryBound(to: FetchContext.self).pointee.locale_callback("NONONONON") {
        let data: Data? = locale.data(using: .utf8, allowLossyConversion: false)
        data?.withUnsafeBytes({ bytes in
            // why is unsafebufferpointer.count a signed integer????????????????
            let count = UInt(bytes.count)
            let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: Int8.self)
            citeproc_rs_write_locale_slot(slot, baseAddress, count)
        })
    }
    

}

public struct CiteprocRsDriver {
    private let raw: OpaquePointer
    private let fetch_ctx: UnsafePointer<FetchContext>
    private static func from_raw(raw: OpaquePointer?, fetch_ctx: UnsafePointer<FetchContext>) -> Self? {
        if let raw = raw {
            return Self.init(raw: raw, fetch_ctx: fetch_ctx)
        } else {
            return nil
        }
    }
    public static func new(options: InitOptions) -> CiteprocRsDriver? {
        let ctx: UnsafeMutablePointer<FetchContext> = UnsafeMutablePointer.allocate(capacity: 1)
        ctx.initialize(to: FetchContext(locale_callback: options.locale_callback))
        let ctx_raw: UnsafeMutableRawPointer! = UnsafeMutableRawPointer(ctx)
        
        let style = options.style;
        let data: Data? = style.data(using: .utf8, allowLossyConversion: false)
        let raw: OpaquePointer? =  data?.withUnsafeBytes({ bytes in
            // why is unsafebufferpointer.count a signed integer????????????????
            let count: UInt = UInt(bytes.count)
            let baseAddress: UnsafePointer<Int8> = bytes.baseAddress!.assumingMemoryBound(to: Int8.self)
            let options = citeproc_rs_init_options(
                style: baseAddress,
                style_len: count,
                locale_fetch_context: ctx_raw,
                locale_fetch_callback: locale_fetch_callback,
                format: CiteprocRs.citeproc_rs_output_format(0) // HTML
            )
            return CiteprocRs.citeproc_rs_new(options)
        })
        return CiteprocRsDriver.from_raw(raw: raw, fetch_ctx: ctx)
    }
}
