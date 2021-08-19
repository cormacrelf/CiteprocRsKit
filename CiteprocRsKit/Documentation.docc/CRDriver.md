# ``CiteprocRsKit/CRDriver``

The central API for interacting with CiteprocRsKit.

## Overview


## Topics

### Initializers

- ``CRDriver/init(style:localeCallback:outputFormat:)``

### Clusters

- ``CRDriver/insertCluster(_:)``
- ``CRDriver/clusterHandle(_:)-7x15h``

### String vs numeric Cluster IDs

One focus of clusters is their identity. A cluster ID might be persisted in a document for years, or be created on the fly.

The primary representation of cluster identity is a numeric ID (``CRClusterId(raw:)``). This is convenent to pass around, as it is just a number.

An alternative representation is a string, which is "interned" at runtime to an ephemeral numeric ``CRClusterId``. A string is more convenient to store long-term.

If you use string IDs at all, then they take over the namespace of numeric IDs. Interned strings should be thought of as opaque references to a string ID. You should not use both explicit numeric IDs and interned string IDs in the same ``CRDriver`` instance.

Strings are permanent. ClusterIds, if they are from interned or random strings, may be ephemeral. If you are interning strings or using random strings at all, ClusterIds should be thought of as opaque references. If you are not, then they can be transparent numbers.

- ``CRDriver/internClusterId(_:)``
- ``CRDriver/randomClusterId()``
- ``CRDriver/clusterHandle(_:)-61ejz``

### Formatted output

- ``CRDriver/formatCluster(clusterId:)``
- ``CRDriver/formatBibliography()``
