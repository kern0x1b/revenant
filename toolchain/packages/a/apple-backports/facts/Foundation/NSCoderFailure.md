# A coder's own recorded failure, iOS 9

Source: the host's own Foundation, macOS 27, through the differential run of
`tests/backports/host/foundation2/run.sh`.

`decodingFailurePolicy` is `NSDecodingFailurePolicyRaiseException` (0) until it is set, on every kind of
coder. `-failWithError:` reads it: under the default, raising, policy it raises
`NSInvalidUnarchiveOperationException` and leaves `-error` nil, as if nothing had happened; under
`NSDecodingFailurePolicySetErrorAndReturn` it raises nothing and stores the error instead, which `-error`
then answers. A second `-failWithError:` under that policy replaces the stored error with the new one,
without complaint; setting the policy itself never fails and is kept from then on.
