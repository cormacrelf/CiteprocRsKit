# CiteprocRsKit

A set of Swift bindings for
[`citeproc-rs`](https://github.com/zotero/citeproc-rs).

This is a SwiftPM package that has a dependency on a pre-built copy of
`citeproc-rs`' FFI library.

## Installation

### Via Xcode

Open up your project's settings page, look under the 'Swift Packages' tab and
add this GitHub repo as a dependency.

### Via Package.swift

For Package.swift, add as below. Follow the docs [here][v1] and [here][v2] for version requirements.

[v1]: https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#package-dependency
[v2]: https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#package-dependency-requirement

```swift
// Package.swift
// ...
dependencies: [
    // exact version best for sub-1.0.0 releases as SwiftPM doesn't consider an
    // 0.x to 0.x+1 change a "major version" despite Semver
    .package(url: "https://github.com/cormacrelf/CiteprocRsKit", .exact("0.4.0")),
],
targets: [
    // and add it as a dependency to a target in your own project
    .target(name: "MyApp", dependencies: ["CiteprocRsKit"])
]
```
