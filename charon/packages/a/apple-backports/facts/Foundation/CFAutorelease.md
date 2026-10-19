# CFAutorelease, iOS 7

Source: the host's own CoreFoundation, through the differential run of
`tests/backports/host/foundation2/run.sh`; the device test holds iOS 6 to the same record.

`CFAutorelease` answers the object it is given, not a copy, and leaves its retain count as it was: an
array retained twice still counts 2 inside the autorelease pool. When the pool drains the object is
released once, and the count is 1 again. It is the release an Objective-C `-autorelease` would make,
for an object that may not be an Objective-C one, and the backport makes it the same way on iOS 6.
