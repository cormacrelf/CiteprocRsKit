# ``CiteprocRsKit/CRDriver``

The central API for interacting with CiteprocRsKit.

## Overview


## Topics

### Initializers

- ``CRDriver/init(style:localeCallback:outputFormat:)``

### References

References describe a book/article/legal case/etc, and its metadata.

Here, they are Swift objects that can be converted to JSON that matches the schema for a single [CSL-JSON "csl-data"][csl-data] object. So they **must have an `"id"` field**, may contain a type, and thereafter any number of CSL variables with values in the shape required.

[csl-data]: https://github.com/citation-style-language/schema/blob/master/schemas/input/csl-data.json

- ``previewReference(_:format:)``
- ``insertReference(_:)``
- ``previewReference(json:format:)``
- ``insertReference(json:)``

### Clusters

Typically one acquires a ``CRClusterHandle`` for a particular ID, and then submits it via  ``CRDriver/insertCluster(_:)``. The handle itself is a reusable, resettable 'staging area' for cluster insertions.

- ``CRDriver/clusterHandle(_:)-3dou5``
- ``CRDriver/insertCluster(_:)``

### String Cluster IDs

For ease of persistence, you can identify clusters using a String instead of chiefly via a number.

One focus of clusters is their identity. A cluster ID might be persisted in a document for years, or be created on the fly.

The primary representation of cluster identity is a numeric ID (``CRClusterId``). This is convenent to pass around, as it is just a number.

An alternative representation is a string, which is "interned" at runtime to an ephemeral numeric ``CRClusterId``. The same can be achieved using random strings generated by the driver. A string is more convenient to store long-term. These IDs are also just integers. They currently start at zero, so you will **immediately get ID collisions if you use both systems, and start overwriting other clusters.**

Strings are permanent. ClusterIds, if they are from interned or random strings, may be ephemeral. If you are interning strings or using random strings at all, ClusterIds should be thought of as opaque references. If you are not, then they can be transparent numbers.

- ``CRDriver/internClusterId(_:)``
- ``CRDriver/randomClusterId()``
- ``CRDriver/clusterHandle(_:)-61ejz``

### Document flow

Where in the document are all these clusters? What order do they appear? Are some in footnotes?
The Driver cannot know if you don't say. So any formatted output will be empty until you do.

- ``CRClusterPosition``
- ``CRDriver/setClusterOrder(positions:)``

### Formatted output

- ``CRDriver/formatCluster(clusterId:)``
- ``CRDriver/formatBibliography()``
