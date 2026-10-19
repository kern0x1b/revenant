# New URL resource keys, iOS 14

Purgeable, sparse, may-have-extended-attributes, may-share-file-content, volume supports file protection, and the two content keys.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The keys are added to the answer of getResourceValue:forKey:error: and resourceValuesForKeys:error: by wrapping the system methods for file URLs. Purgeable and may-share are NO; sparse compares the allocated blocks with the size; extended attributes use listxattr; file protection is YES on a volume that reports NSFileProtectionKey. NSURLContentTypeKey and NSURLFileContentIdentifierKey answer no value: the first needs UTType, the second a file system identifier of a later release.
