# NSDirectoryEnumerator isEnumeratingDirectoryPostOrder, iOS 13

The property is NO on an enumerator that visits directories before their contents.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The enumerator the release creates has no option for the post order, so the answer is always NO, as the host's is for the enumerators made without the option.
