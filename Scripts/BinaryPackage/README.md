# ffi-xcframework

Distribution repo for pre-built binaries of CiteprocRs.xcframework, the FFI module
from [citeproc-rs](https://github.com/zotero/citeproc-rs), built for use in
the Swift bindings for it,
[CiteprocRsKit](https://github.com/cormacrelf/CiteprocRsKit).

The Package.swift file here simply refers to a download URL on the
CiteprocRsKit repo, along with a checksum.

There's not much use depending on this directly in SwiftPM -- you want to add
CiteprocRsKit instead.

```swift
// set TAG to an appropriate version etc
.package(url: "https://github.com/cormacrelf/CiteprocRsKit", from: "TAG"),
```

