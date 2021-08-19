# ``CiteprocRsKit``

A wrapper for `citeproc-rs` in Swift.

## Overview

See [`citeproc-rs`][rs] for more information.

[rs]: https://github.com/zotero/citeproc-rs

## Topics

### Getting Started

- ``CRDriver``
- ``CROutputFormat``

### Error handling

Note also that nearly every operation in the entire library is explicitly `throws`;

- ``CRError``
- ``CRErrorCode``

### References

References describe a book/article/legal case/etc, and its metadata.

Here, they are Swift objects that can be converted to JSON that matches the schema for a single [CSL-JSON "csl-data"][csl-data] object. So they must have an `"id"` field, may contain a type, and thereafter any number of CSL variables with values in the shape required.

[csl-data]: https://github.com/citation-style-language/schema/blob/master/schemas/input/csl-data.json

- ``CRDriver/previewReference(_:format:)``
- ``CRDriver/insertReference(_:)``

### Citation clusters

A cluster is a list of cites, identified with either a string or a `UInt32`. Each cite contains a string that should match one of the References known to the Driver.

See also: ``CRDriver/insertCluster(_:)``, and ClusterId-related methods ``CRDriver/internClusterId(_:)``, ``CRDriver/clusterHandle(_:)-3dou5``, ``CRDriver/clusterHandle(_:)-61ejz``

- ``CRClusterHandle``
- ``CRCiteHandle``
- ``CRClusterId``

### Document flow

Where in the document are all these clusters? What order do they appear? Are some in footnotes?

- ``CRClusterPosition``
- ``CRDriver/setClusterOrder(positions:)``

### Logging

CiteprocRsKit is capable of forwarding all of `citeproc-rs`' logs to the destination of your choice.

- ``CRLog``
- ``CRLogger``
- ``CRLogLevel``
- ``CRLevelFilter``
- ``CROSLogger``
