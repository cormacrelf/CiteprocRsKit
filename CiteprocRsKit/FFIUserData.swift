//
//  FFIUserData.swift
//  CiteprocRsKit
//
//
//
//  Created by Cormac Relf on 30/7/21.
//

import Foundation

/// A tool to pass a Swift object by reference into Rust code and recover it in a callback.
/// This is essentially a class wrapper for any T, that handles our Unmanaged pointer usage.
class FFIUserData<T> {
    var inner: T
    init(_ inner: T) {
        self.inner = inner
    }

    /// Borrows this instance to use in a call to an FFI function. The resulting object is useful as user data in a callback-based API.
    /// Importantly, this is unretained. So you will be expected to keep an owned version hanging around such that this
    /// reference is not deallocated.
    ///
    /// If we passed a reference with an unbalanced retain (`Unmanaged.passRetained(self)`) to Rust,
    /// then the instance would be leaked at some point, because Rust is not aware it has to issue a corresponding -1 release
    /// when the Driver is dropped. Indeed, if you additionall made reconstruct do `takeRetainedValue`, then you could only
    /// reconstruct the pointer once, like so:
    ///
    ///     Sequence            ... Strong count    Weak count      Unowned count
    ///     init()              ... +1              +1
    ///     borrow()
    ///         passRetained()  ... +2
    ///     reconstruct()
    ///         takeRetained()  ... +2 (-1 unbalanced release, +1 creation of reference)
    ///     drop reconstructed  ... +1
    ///     reconstruct()
    ///         takeRetained()  ... +1 (-1 unbalanced release, +1 creation of reference)
    ///     drop reconstructed  ... 0 (deinit)
    ///
    /// You can see this in action by changing to `passRetained()` / `takeRetainedValue()` and running only
    /// the test`MemoryTests.testUserDataManyReconstructions()`, which then fails on the third iteration.
    ///
    /// The crucial thing to note in usage of FFIUserData is that you must not drop your own reference to the user data while
    /// there are live pointers that may yet be reconstructed.
    /// If you do, this happens:
    ///
    ///     let owned = Optional(.init())       ... +1
    ///     borrow() = passUnretained()         ... +1
    ///     owned = nil                         ... +0 (deinit)
    ///     reconstruct()                       ...    (invalid)
    ///
    internal func borrow() -> UnsafeMutableRawPointer {
        // weak var selfself = self;
        return UnsafeMutableRawPointer.init(Unmanaged.passUnretained(self).toOpaque())
    }

    /// Recovers a Swift object from a pointer (from borrow). Use this in the callback itself.
    internal static func reconstruct(_ raw: UnsafeMutableRawPointer) -> Self {
        let unmanaged: Unmanaged<Self> = Unmanaged.fromOpaque(raw)
        return unmanaged.takeUnretainedValue()
    }
}
