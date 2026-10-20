# NSOperationQueue barrier and progress, iOS 13

addBarrierBlock: and the progress property.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The barrier is a gate operation that depends on every operation added before it, and every operation added after depends on it. The gate is visible in dependencies and operationCount. progress counts the operations: the total grows as they are added and the completed count as they finish, and the values follow the host in the differential run.
