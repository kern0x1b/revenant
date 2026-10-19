# The buffer API of Compression: formats, answers and what the layer does

The layer is `packages/a/apple-backports/Compression/CompressionBuffer.c`. Its facts are measured on the host's own
libcompression (macOS, the same process as the port), not read from a header or a disassembly. The differential that
checks them is `tests/backports/host/compression/run.sh` (seed as argument; it prints the seed).

## Formats (measured)

- LZFSE: the stream starts `bvx2`, from the lzfse-1.0 codec.
- ZLIB: raw deflate, no zlib header and no checksum (the window is -15).
- LZ4: framed blocks of Apple's own: `bv41` for a compressed block (raw size, packed size, then the LZ4 block), `bv4-`
  for a stored block (raw size, then the bytes), `bv4$` for the end. A block carries up to 65536 raw bytes and depends
  on the 64 KiB before it: a block after the first does not decode without that dictionary.
- LZ4_RAW: one bare LZ4 block, no header.
- LZMA: the xz container (it starts `fd 37 7a 58 5a 00`), no integrity check (the stream flags are `00 00`), at liblzma's
  preset 6. Measured on the host: the layer's output is identical to the host's for 1000 bytes of `a` (72 bytes) and for
  300000 bytes of words (226012 bytes). Every other preset differs on the 300000-byte input (preset 5 also matches on
  the 1000 bytes; a one-off survey,
  not kept; the differential requires the bytes of every LZMA case: `LZMA encodes the host's bytes`). The codec is xz 5.8.4
  (packages/x/xz), built from its own sources and a configuration header of this repository (packages/x/xz/config.h).

## Empty input (measured)

LZFSE 12 bytes; ZLIB 2 bytes; LZ4 4 bytes (`bv4$`); LZ4_RAW 0 bytes (0 is also the error answer); LZMA 32 bytes (the
xz stream header, an empty block-less stream, and its index and footer).

## Destinations (measured)

- Encode: the size of the output depends on the destination. LZ4 writes a block stored instead of compressed when the
  compressed form does not fit the room left; LZFSE and the LZ4 codec refuse an exact fit. The layer encodes into a
  buffer that always fits and copies out when the result fits, so the answer does not depend on the destination.
  Encode into a destination that is too small answers 0.
- Decode into a destination too small for the content: the host writes the first `dst` bytes and answers `dst` (LZFSE,
  ZLIB, LZ4, LZ4_RAW). LZMA answers 0 (measured: the host answers 0 too, for every size and destination the
  differential tries).
- Corrupt input (a fixed random 64-byte pattern, and every codec's bad frame): answers 0 on all five algorithms.
- A NULL scratch buffer is allowed on encode and decode for every algorithm, and answers the same as with one (measured
  with 1000 bytes of `a`: LZFSE 38, ZLIB 11, LZ4 149, LZ4_RAW 133 bytes). The layer allocates its own when it is NULL.

## Truncated input (measured)

- LZFSE and LZ4 framed: every prefix of host output answers the same as the host (seed 1 and seed 2, no failure).
- LZ4_RAW: a prefix that ends at the end of a sequence answers the bytes decoded so far (after its literals, or after its
  match); a cut inside a sequence answers 0. The layer walks the sequences itself (`decode_lz4_raw`).
- ZLIB: NOT settled. The host answers the decoded prefix for some cuts and 0 for others (for example random 4095 bytes
  answer the prefix at every cut, words 4095 answer 0 at every cut but the end). The layer answers 0 at every cut that
  is not the end. This is a known difference: see the crutch entry `charon: ZLIB truncated streams`, and the
  differential reports it as KNOWN-DIFF by name.
  One measured attempt at the rule (seed 1): answer the bytes decoded so far on any Z_BUF_ERROR, as an eager decoder
  would. It is worse: 10234 truncation failures (the host answers 0 inside a dynamic block, so an eager answer is wrong
  there), against 9135 for the layer's rule. The layer's rule is kept.
- ZLIB, a rule tested and not the host's (v-int-c13; probe runs/v-int-c13/probe/zlib_status.c, black box). The tested rule:
  the buffer answer is the output count of the host's stream decoder run to FINALIZE on the same prefix when the stream ends
  OK or END, and 0 when it ends in ERROR. Measured per prefix on zeros 2, 3, 255, words 4095, random 4095 and mix 4095, with
  the stream run to FINALIZE in four shapes (all input at once, and chunks of 1, 7 and 4096 bytes, each followed by FINALIZE
  calls): words 4095 and mix 4095 agree at every prefix; random 4095 (one stored block) disagrees at 4094 of its 4100
  prefixes (the buffer answers the stored bytes present, the stream answers ERROR with the same count); zeros 2, 3 and 255
  disagree at len - 1 (the buffer answers the whole output, 2, 3 and 255 bytes, where the stream answers ERROR with 0 bytes).
  The probe's function check finds one prefix pair with the same stream answer (ERROR, 0) and different buffer answers, so
  the buffer answer is not a function of the stream's status and count. A single FINALIZE call on the prefix (not run to
  FINALIZE) answers OK with output where the buffer answers 0 (1969 prefixes of words 4095), so it is not the stream's end
  state either. The layer's rule is kept; the entry stays open.

## Short destination for LZ4_RAW (measured)

The answer for a destination shorter than the content follows the host's order inside a sequence: the token, the literal
length, the literal run, the 2-byte offset, the match length, the match. Measured on the host's own block of 65536 bytes
(content 3, the differential's seed 1 input) with byte edits and cuts at sequences 0, 440, 883 and the last literal run
(probe runs/v-int-c13/probe/lz4raw_matrix.c, output lz4raw.matrix.65536.out; black box):
- a literal run the input does not hold (a cut inside it) answers 0 for every destination that reaches its sequence, the
  destination equal to the sequence's start included; below the sequence's start the answer is the destination;
- a destination that fills inside a literal run the input holds answers its size: the offset is not read yet;
- at the end of the literal run the offset is read: an offset of 0, or beyond the output so far, answers 0 for that
  destination and every larger one; a cut inside the offset does the same;
- valid blocks answer their size for every destination (the match is copied up to the destination).

The layer follows this order in `decode_lz4_raw`: the literal run is checked against the input before it is copied into the
room of the destination. Before, the room was checked first, so a destination that filled inside a run the input does not
hold answered its size where the host answers 0.

The measured failures of the differential were this case. Its "host encode one byte short" writes a different stream into
the same buffer before the destination sweep (run.sh), and the sweep decodes that buffer. The stream then holds a sequence
whose literal run is cut by the input: seed 1, n = 65536, the sequence at output 65494 (its literal bytes start at input 37342,
117 of them, and the stream is 37415 bytes); seed 2, n = 65537, the sequence at output 65389 (input 37302, 241 bytes, stream
37452 bytes). The host answers 0 for every destination from that output to n, and the destination below it. The seed 1
n = 300000 case has the same shape (answers 0 from output 299961 to n). The differential now checks these shapes as well
(`lz4raw_cut_and_corrupt`: the cuts and edits above at the last sequences, for content 3 at sizes from 4096): with the
pre-fix order, 32 of them fail at seed 1 (the control run), and with this order none does.

An earlier probe (v-int-c3, measured) used the host's own encoder with other random bytes and destinations n-1 to n/2, and
the host answered the full destination every time. It did not reproduce the differential's inputs (their generator order)
or the short encode that leaves the cut run in the buffer, which is why it found no rule.

## Scratch sizes (measured, not compared)

The layer's `compression_encode_scratch_buffer_size` and `compression_decode_scratch_buffer_size` answer the codec's own
sizes, which differ from the host's (seed 2 run): LZFSE encode 684384 (host 684288), LZFSE decode 47368 (host 47376);
ZLIB answers 0 for both (host 270336 encode, 131072 decode); LZ4 answers 0 for both (host 32768 encode, 0 decode);
LZ4_RAW answers 0 for both (host 32768 encode, 0 decode); LZMA answers 0 for both (host 0 encode, 30080 decode; seeds 1
and 2 run). The layer uses its own state for ZLIB and LZ4 and ignores the
scratch. The LZFSE encode size is larger than the host's by 96 bytes, so an app that hard-codes the host's number would
hand the codec too little; an app that allocates the size our function gives it is right. Not a contract with the host.

## Encoded bytes: what is required (decided, measured)

The bytes the layer encodes are required to equal the host's for LZMA only. For LZFSE, ZLIB, LZ4 and LZ4_RAW the contract is
cross-decoding, for every size, content, chunking and seed: what the layer encodes, the host decodes to the input, and what
the host encodes, the layer decodes to the input. Apple's API promises a stream in the algorithm's format, not Apple's
encoder's bytes, and the layer's encoders for those four are not Apple's.

Measured (seed 1 and seed 2, 340 encode cases each: 5 algorithms x 17 sizes x 4 contents), the layer's bytes equal the
host's in:

| algorithm | seed 1 | seed 2 |
|-----------|--------|--------|
| LZFSE     | 65 of 68 | 66 of 68 |
| ZLIB      | 56 of 68 | 56 of 68 |
| LZ4       | 38 of 68 | 39 of 68 |
| LZ4_RAW   | 33 of 68 | 34 of 68 |
| LZMA      | 68 of 68 (required) | 68 of 68 (required) |

Seed 1 total for the four reported algorithms: 192 of 272 (260 of 340 with LZMA). The counts are reported by the
differential, not required. The empty input is the one case where the bytes are shown to differ in format: the host's LZ4
stream of nothing is 12 bytes (`bv4-` with raw size 0, then `bv4$`), the layer's is 4 bytes (`bv4$`). The rule holds for
it: the host's stream API decodes the layer's 4 bytes to END with 0 bytes, and the layer decodes the host's 12 bytes to END
with 0 bytes (the stream checks, seeds 1 and 2). It is not a format defect.

## Streams (measured)

- Progress (measured on the host, probe in runs/v-int-c8/probe/progress.c, 300000 bytes, the four contents, chunks of 1, 7,
  4096, 65536 and all bytes). T is the input offset at which output first appears with 1-byte chunks; "before" is the
  output written before FINALIZE with 1-byte chunks; "events" is the number of chunks that wrote output.

  | algorithm | zeros | words | random | runs |
  |-----------|-------|-------|--------|------|
  | LZFSE  T | none | 60666 | 41248 | 81653 |
  | LZFSE  before / events | 0 / 0 | 96894 / 4 | 281006 / 7 | 130964 / 3 |
  | ZLIB   T | none | 74778 | 16645 | 32153 |
  | ZLIB   before / events | 0 / 0 | 90278 / 3 | 295326 / 18 | 156228 / 9 |
  | LZ4    T | 65536 | 65536 | 65536 | 65536 |
  | LZ4    before / events | 1592 / 4 | 180843 / 4 | 262176 / 4 | 149759 / 4 |
  | LZMA   T | 1 | 1 | 1 | 1 |
  | LZMA   before / events | 24 / 1 | 61469 / 2 | 242453 / 5 | 122914 / 3 |

  The rule the table supports: the first output comes at the first chunk boundary at or after T, that is
  ceil(T / chunk) * chunk, for every content and chunk measured (for example LZFSE words: 60669 at chunk 7, 61440 at 4096, 65536
  at 65536). Only the threshold T belongs to the codec and the content; the chunking only rounds it up. LZ4's threshold is
  its 64 KiB block; LZMA's is its first input byte, where the xz header is written; ZLIB's and LZFSE's are where the host's own
  encoder ends a deflate block or an LZFSE block, which the format leaves open (measured at 16645 to 81653 for non-zero content).
  Zeros give ZLIB and LZFSE no output before FINALIZE at any chunking. The host's LZFSE output for zeros depends on the
  chunking in its bytes (322 bytes at the whole input, 1184 at 1-byte chunks), so those bytes are reported, not required;
  ZLIB's zeros are 307 bytes at every chunking.
- The allowance, per codec (the differential's progress check, required): for each chunking, the layer writes output before
  FINALIZE whenever the host does, and its first output is within the allowance of the host's, rounded up to the chunk. The
  allowance is 0 for LZ4 and LZMA (their thresholds are the codec's own: the same block, the same header), and 65536 for ZLIB
  and LZFSE (one 64 KiB block: the format leaves the host's block ends open). A host that writes nothing before FINALIZE
  (zeros with ZLIB or LZFSE) holds the layer to nothing.
- The decode allowance of the host's own stream (v-int-c11, differential: decode_allowance): LZFSE's is 0, because the port
  decodes each block as the host does and an LZVN block as its bytes come (the LZFSE block section below); LZ4, LZMA and ZLIB
  keep the allowance above. The encode allowance is unchanged.
- The decode count before FINALIZE (rule, measured, v-int-c10; differential: stream_checks, "as much output before FINALIZE"):
  for every codec and chunking, port_before >= host_before - allowance, where the allowance is the decode allowance (0 for
  LZFSE, LZ4 and LZMA; 65536 for ZLIB), and the final bytes and the status are equal. The reason: the API lets a decoder write
  output into the caller's buffer as soon as it has it, so a port that writes more before FINALIZE than the host has given
  its bytes earlier, within the bound of its own memory; a port that writes less is the defect. Measured with the whole
  input in one call (the host's own stream): the host writes 131072 bytes before FINALIZE for 300000 zeros, 196608 for
  words, 253227 for runs (ZLIB), and the port writes all it can (300000); with 1-byte and 7-byte chunks the two agree. LZFSE,
  LZMA and LZ4 agree with the host within the rule at every chunking measured (seeds 1 and 2, failures=0).
- The layer's own thresholds, which the check measures: LZ4 writes each 64 KiB block when it is complete (T = 65536). LZMA's
  stream encoder and decoder run under LZMA_RUN, so the first byte gives the header. ZLIB runs deflate and inflate with
  Z_NO_FLUSH, so its output comes where zlib's own deflate writes it. LZFSE encodes 32 KiB blocks: the host's first output
  is at 41248 bytes or more (measured above), so a block of 64 KiB would write nothing before FINALIZE for inputs under 64 KiB
  where the host does (the first run of the differential failed 8 checks that way, at 65535 bytes); a 32 KiB block writes
  before the host does in every measured case, within 65536.
- LZFSE decoding progress of the host (measured, probe runs/v-int-c9/probe/decode_progress.c, the host decoding its own
  stream: T is the first output at 1-byte chunks, the next column the first output at 7, 4096, 65536 and all bytes, and
  "events" the chunks that wrote output at 1 byte). The host writes each block's output as the block completes, so the
  first output is at the first chunk boundary at or after T, capped at the stream's length (for example 300000 words at
  4096: T 25117, boundary 28672; 65535 words at 4096: T 25117, the stream is 27382 bytes long, so 27382).

  | input | content | T | 7, 4096, 65536, all | events |
  |-------|---------|---|---------------------|--------|
  | 300000 | zeros  | 318   | 322, 322, 322, 322           | 1 |
  | 300000 | words  | 25117 | 25123, 28672, 65536, 120307  | 5 |
  | 300000 | random | 40300 | 40306, 40960, 65536, 303089  | 8 |
  | 300000 | runs   | 43371 | 43372, 45056, 65536, 160160  | 4 |
  | 65535  | zeros  | 180   | 182, 184, 184, 184           | 1 |
  | 65535  | words  | 25117 | 25123, 27382, 27382, 27382   | 2 |
  | 65535  | random | 40300 | 40306, 40960, 65536, 66290   | 2 |
  | 65535  | runs   | 35049 | 35049, 35053, 35053, 35053   | 1 |

- LZFSE blocks and the window (measured, probes runs/v-int-c9/probe/blocks.c and window.c, 300000 bytes): the host's stream
  is a run of blocks, and a block decodes alone only when its matches reach nothing before it. Blocks by content, raw bytes
  (the block's output) and the least history the block needs (the bytes before it, found by handing the decoder those bytes
  as a stored block in front of the block):
  - zeros: 1 block of 300000 raw bytes (318 stream bytes), history 0;
  - words: 5 blocks of 58902 to 60308 raw bytes, history 0 for block 0, then 40281 to 55951;
  - random: 8 blocks of 21733 to 39901 raw bytes, history 0 for blocks 0, 2 and 6, then 12004 to 94193;
  - runs: 4 blocks of 54505 to 82140 raw bytes, history 70412, 148927 and 194910 for blocks 1 to 3.
  The largest history measured is 194910 bytes, and the encoder never writes a match farther back than
  LZFSE_ENCODE_MAX_D_VALUE (262139, lzfse_internal.h). So a block decoder keeps a window of the last 262139 output bytes,
  not the input, and a block's output is its raw size. Standalone decoding of the blocks fails for the blocks that need
  history (words 4 of 5, random 5 of 8, runs 3 of 4); it does not for block 0 of each content.
- Memory: the stream holds one block of pending input (up to 128 KiB for LZ4 decoding, which must hold a whole block), one
  block of output (up to 128 KiB), the 64 KiB LZ4 dictionary, and the codec's own state (zlib's and liblzma's windows). It does
  not hold the whole input or output, except one LZFSE block (below).
- LZFSE decoding is block by block. The layer reads each block's size from its header, with the codec's own header types
  (lzfse_internal.h, installed by packages/l/lzfse) and the packed fields as lzfse_decode_base.c reads them, and decodes a
  block when it is whole (an LZVN block with raw bytes is the exception: decoded as its bytes come, below). The block is decoded
  after the window of output before it: the window goes in front of the block
  as a stored block, so the codec reads the block's matches from it (up to LZFSE_ENCODE_MAX_D_VALUE, 262139 bytes).
  A stored block's bytes come out as they arrive, as the host's do (measured with 1-byte chunks: the first output at byte 9
  of a stream whose first block is stored, 8 header bytes and one byte). The host also writes an LZVN block's bytes before
  the block ends (measured on 15-byte inputs: first output at byte 16 of a 26-byte block). The layer does the same, from
  v-int-c11: an LZVN block with raw bytes is decoded by upstream's own resumable state (lzvn_decoder_state, lzvn_decode_base.h,
  installed by packages/l/lzfse) carried across calls. Each call runs the codec on the payload bytes the caller has, and the
  bytes it completes are written; a match or an instruction it cannot finish waits for the next call, and an
  end-of-stream opcode with raw bytes or payload left over is a corrupt block. Measured: the differential's decode check
  with the LZFSE decode allowance at 0 passes for every chunking (seeds 1 and 2, failures=0, the first output and the count
  before FINALIZE). Control: with the LZVN start disabled, 32 checks fail at seed 1 (the 26-byte block is written at its
  end: first output 26 against the host's 16).
  Memory: the window, one block of input, one block of output, and the window's copy in the frame: at most three windows
  and two blocks. Decoding of ZLIB, LZMA and LZ4 is incremental and its progress is not compared with the host's (the
  differential checks the LZFSE decode progress, and every decode's final bytes and status).
- The bytes of the stream: LZFSE is written as one block after another, each without its end marker, and `bvx$` is written
  once at FINALIZE; the empty stream of LZFSE is the codec's own (12 bytes). LZ4 writes its framed blocks and `bv4$` once.
- Stream bytes do not depend on the input chunking or the output pieces, in the layer (checked against its own one-piece
  output) and in the host (measured for LZFSE, ZLIB, LZ4 and LZMA: 1, 7, 4096 and all bytes at a time).
- The empty stream, buffer API: LZFSE 12 bytes (the stored block of 0 bytes, then `bvx$`); LZ4 12 bytes on the host, 4 in
  the layer (above); LZMA 32 bytes. ZLIB 2 bytes. A decode of a valid empty stream answers END with 0 bytes through the
  stream API, and ERROR for a corrupt one; the buffer API answers 0 for both, as the host does.
- Status of a decode (the layer's rule, one per codec): done with n bytes, full (the destination filled before the stream
  ended), or failed. LZFSE answers 0 for both an empty stream and a corrupt one, so a 0 answer is done only when the block
  headers of the input are empty stored blocks ending in `bvx$`. LZMA uses liblzma's stream decoder, because its buffer
  decoder answers LZMA_BUF_ERROR for both a full destination and a cut stream. Measured before that rule: the stream API
  failed 300000 zeros (a stream of a few hundred bytes) in its first destination of 66 KiB; the differential's content
  class for that case is `content=0`.
