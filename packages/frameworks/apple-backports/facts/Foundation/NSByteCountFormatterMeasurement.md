# NSByteCountFormatter measurement members, iOS 13

stringFromMeasurement: in both forms.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The measurement is converted to bytes and formatted by the existing byte-count path. Values of 2^63 bytes and above are formatted by the port itself with half-up rounding, because the release counts in a signed 64-bit integer. The digit rules and the both-off-becomes-both-on rule follow the host. A difference remains: with a beyond-2^63 value and several units in allowedUnits, the chosen unit can differ from the host.

From 2^53 bytes up the port formats the count itself, because the digits the release's number formatter writes for a
double that large stop at fifteen. A byte count below 2^63 is written exactly, a larger one or a count in a larger unit
as the shortest digits that name the double. The host's last digit of a count in a large unit can differ by one or two
units of the last place, which the host run tolerates from 16 digits up; a negative count that large is skipped, since
the host answers it with a wrapped-around number. Below 2^53 the release's formatter is used, with the zeros it adds
after a count of bytes taken away.
