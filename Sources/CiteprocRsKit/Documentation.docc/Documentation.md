# ``CiteprocRsKit``

A wrapper for `citeproc-rs` in Swift.

## Overview

See [`citeproc-rs`][rs] for more information.

[rs]: https://github.com/zotero/citeproc-rs

## Topics

### Fundamentals

`CRDriver` is the main set of APIs.

- ``CRDriver``
- ``CROutputFormat``

### Error handling

Nearly every operation in the entire library is explicitly `throws`; this means even the smallest error on the FFI boundary results in a stack trace.
Notably, every panic that unwinds to the FFI boundary is caught and thrown as a Swift exception, with the backtrace logged to your logger of choice.

- ``CRError``
- ``CRErrorCode``

### Citation clusters

A cluster is a list of cites. Each cite contains a string that should match one of the References known to the Driver. The cluster as a whole is identified with either a string or a `UInt32`. 

See also: ``CRDriver/insertCluster(_:)``, and other methods on ``CRDriver``.

- ``CRClusterHandle``
- ``CRClusterId``
- ``CRCite``

### Document flow

Where in the document are all these clusters?

- ``CRClusterPosition``

### Logging

CiteprocRsKit is capable of forwarding all of `citeproc-rs`' logs to the destination of your choice.

- ``CRLog``
- ``CRLogger``
- ``CROSLogger``
- ``CRLogLevel``
- ``CRLevelFilter``

### References

To pass reference data into ``CRDriver``, you can use either raw JSON `Data` or any kind of `Encodable`
value that produces CSL-JSON. For convenience a set of types that do that is provided.

- ``CslReference``
- ``CslVariable``
- ``CslName``
- ``CslDate``
- ``CslTitle``
- ``NumString``
