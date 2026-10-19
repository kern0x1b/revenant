# NSData compression, iOS 13

compressedDataUsingAlgorithm:error:, decompressedDataUsingAlgorithm:error: and the mutable pair, for LZFSE, LZ4, LZMA and ZLIB.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

ZLIB is raw deflate, through libz opened with dlopen. LZ4 is written with the bv41, bv4- and bv4$ block framing and reads it back; the declared size is ignored and trailing bytes are refused, as the host does. LZMA is the xz container with LZMA2, written from the public format specification, with the padding, CRC and range-decoder checks the host makes. LZFSE has no public specification: the port writes stored blocks only and reads stored blocks; a stream with compressed LZFSE blocks fails with NSCocoaErrorDomain code 4864. The differential run compares round trips and the rejection of damaged input.
