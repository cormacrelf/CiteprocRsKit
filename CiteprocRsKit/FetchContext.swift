//
//  FetchContext.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 28/7/21.
//

import CiteprocRs
import Foundation

struct FetchContext {
    internal init(locale_callback: @escaping (String) -> String?) {
        self.locale_callback = locale_callback
    }

    let locale_callback: (String) -> String?
}

/// If this callback is used, then there must be a FetchContext supplied to
func localeFetchCallback(
    contextRaw: UnsafeMutableRawPointer?, slot: OpaquePointer?,
    langNulTerminated: UnsafePointer<Int8>?
) {
    guard let langNulTerminated = langNulTerminated, let contextRaw = contextRaw else {
        return
    }
    // lang_cstr is null terminated. Let Swift turn it into a string.
    let lang = String.init(cString: langNulTerminated)

    let fetchContext: FFIUserData<FetchContext> = FFIUserData.reconstruct(contextRaw)
    guard let locale = fetchContext.inner.locale_callback(lang) else {
        return
    }
    let data: Data? = locale.data(using: .utf8, allowLossyConversion: false)
    data?.withCharPointer({ baseAddress, count in
        CiteprocRs.citeproc_rs_locale_slot_write(
            slot: slot, locale_xml: baseAddress, locale_xml_len: count)
    })
}
