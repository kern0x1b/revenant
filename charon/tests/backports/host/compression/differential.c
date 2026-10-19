#include <compression.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

size_t charon_host_compression_encode_buffer(uint8_t *, size_t, const uint8_t *, size_t, void *, compression_algorithm);
size_t charon_host_compression_decode_buffer(uint8_t *, size_t, const uint8_t *, size_t, void *, compression_algorithm);
size_t charon_host_compression_encode_scratch_buffer_size(compression_algorithm);
size_t charon_host_compression_decode_scratch_buffer_size(compression_algorithm);
compression_status charon_host_compression_stream_init(compression_stream *, compression_stream_operation, compression_algorithm);
compression_status charon_host_compression_stream_process(compression_stream *, int);
compression_status charon_host_compression_stream_destroy(compression_stream *);

static const compression_algorithm kAlgorithms[] = {COMPRESSION_LZFSE, COMPRESSION_ZLIB, COMPRESSION_LZ4, COMPRESSION_LZ4_RAW, COMPRESSION_LZMA};
static const char *kNames[] = {"LZFSE", "ZLIB", "LZ4", "LZ4_RAW", "LZMA"};
static const size_t kSizes[] = {0, 1, 2, 3, 4, 5, 15, 16, 17, 255, 256, 4095, 4096, 65535, 65536, 65537, 300000};
static const int kClasses = 4;

static int checks = 0, failures = 0, encoded_cases = 0;
static int equal_bytes[5];
static unsigned long long state;

enum { kKnownZLIBTruncation, kKnownRows };
static const char *kKnownNames[kKnownRows] = {"charon: ZLIB truncated streams"};
static int known[kKnownRows];

static unsigned next_random(void)
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return (unsigned)(state >> 11);
}

static void fill(uint8_t *buffer, size_t size, int content)
{
    static const char words[] = "the quick brown fox jumps over the lazy dog 0123456789 ";
    for (size_t i = 0; i < size; i++) {
        switch (content) {
        case 0: buffer[i] = 0; break;
        case 1: buffer[i] = (uint8_t)words[(i + next_random() % 3) % (sizeof words - 1)]; break;
        case 2: buffer[i] = (uint8_t)next_random(); break;
        default: buffer[i] = (i / 37) % 2 ? (uint8_t)next_random() : 'a'; break;
        }
    }
}

static int decodes(size_t len, const uint8_t *stream, size_t n, const uint8_t *input, uint8_t *back, size_t cap, void *work,
                   compression_algorithm algorithm)
{
    size_t decoded = compression_decode_buffer(back, cap, stream, len, work, algorithm);
    return decoded == n && (n == 0 || memcmp(back, input, n) == 0);
}

static char where[96];

static void check(int ok, const char *what, int a, int b)
{
    checks++;
    if (ok) return;
    failures++;
    printf("FAIL %s [%s]: %d vs %d\n", what, where, a, b);
}

static void check_known(int ok, int row, int predicate, const char *what, int a, int b)
{
    checks++;
    if (ok) return;
    if (predicate) {
        known[row]++;
        return;
    }
    failures++;
    printf("FAIL %s [%s]: %d vs %d\n", what, where, a, b);
}

typedef struct {
    compression_status (*init)(compression_stream *, compression_stream_operation, compression_algorithm);
    compression_status (*process)(compression_stream *, int);
    compression_status (*destroy)(compression_stream *);
} stream_api;
static const stream_api kHostStream = {compression_stream_init, compression_stream_process, compression_stream_destroy};
static const stream_api kPortStream = {charon_host_compression_stream_init, charon_host_compression_stream_process,
                                       charon_host_compression_stream_destroy};

#define NO_OUTPUT ((size_t)-1)

static size_t stream_run(const stream_api *api, compression_stream_operation op, compression_algorithm alg, const uint8_t *in,
                         size_t n, size_t chunk, size_t piece, uint8_t *out, size_t cap, size_t *before, size_t *first,
                         compression_status *status)
{
    compression_stream s;
    memset(&s, 0, sizeof s);
    *before = 0;
    *first = NO_OUTPUT;
    *status = COMPRESSION_STATUS_ERROR;
    if (api->init(&s, op, alg) != COMPRESSION_STATUS_OK) return 0;
    *status = COMPRESSION_STATUS_OK;
    size_t off = 0, written = 0;
    while (off < n && *status == COMPRESSION_STATUS_OK) {
        size_t c = n - off < chunk ? n - off : chunk;
        s.src_ptr = in + off;
        s.src_size = c;
        while (s.src_size && *status == COMPRESSION_STATUS_OK) {
            size_t room = cap - written;
            s.dst_ptr = out + written;
            s.dst_size = piece && piece < room ? piece : room;
            *status = api->process(&s, 0);
            written = (size_t)(s.dst_ptr - out);
        }
        off += c;
        if (*first == NO_OUTPUT && written) *first = off;
    }
    *before = written;
    s.src_ptr = in + n;
    s.src_size = 0;
    for (long guard = 0; *status == COMPRESSION_STATUS_OK && guard < 100000000; guard++) {
        size_t room = cap - written;
        s.dst_ptr = out + written;
        s.dst_size = piece && piece < room ? piece : room;
        *status = api->process(&s, COMPRESSION_STREAM_FINALIZE);
        written = (size_t)(s.dst_ptr - out);
    }
    api->destroy(&s);
    return written;
}

static const char *name_of(compression_algorithm algorithm)
{
    for (size_t a = 0; a < sizeof kAlgorithms / sizeof *kAlgorithms; a++) {
        if (kAlgorithms[a] == algorithm) return kNames[a];
    }
    return "?";
}

static size_t progress_allowance(compression_algorithm algorithm)
{
    return algorithm == COMPRESSION_ZLIB || algorithm == COMPRESSION_LZFSE ? 65536 : 0;
}

static size_t decode_allowance(compression_algorithm algorithm)
{
    return algorithm == COMPRESSION_LZFSE ? 0 : progress_allowance(algorithm);
}

static void stream_checks(compression_algorithm algorithm, int content, const uint8_t *input, size_t n, uint8_t *host_out,
                          uint8_t *port_out, uint8_t *ref, uint8_t *back, size_t cap)
{
    static const size_t kChunks[] = {0, 1, 7, 4096};
    size_t before_h = 0, before_p = 0, first_h = NO_OUTPUT, first_p = NO_OUTPUT, ignored = 0, host_n, ref_n = 0, port_n, back_n;
    compression_status st_h = COMPRESSION_STATUS_ERROR, st_p = COMPRESSION_STATUS_ERROR;
    size_t all = n ? n : 1;
    host_n = stream_run(&kHostStream, COMPRESSION_STREAM_ENCODE, algorithm, input, n, all, 0, host_out, cap, &before_h, &first_h, &st_h);
    check(st_h == COMPRESSION_STATUS_END, "host stream encode ends at FINALIZE", (int)st_h, COMPRESSION_STATUS_END);
    for (size_t k = 0; k < sizeof kChunks / sizeof *kChunks; k++) {
        size_t chunk = kChunks[k] ? kChunks[k] : all;
        snprintf(where, sizeof where, "%s n=%zu content=%d stream chunk=%zu", name_of(algorithm), n, content, chunk);
        port_n = stream_run(&kPortStream, COMPRESSION_STREAM_ENCODE, algorithm, input, n, chunk, 0, port_out, cap, &before_p, &first_p, &st_p);
        check(st_p == COMPRESSION_STATUS_END, "port stream encode ends at FINALIZE", (int)st_p, COMPRESSION_STATUS_END);
        if (k == 0) {
            ref_n = port_n;
            memcpy(ref, port_out, port_n);
        }
        check(port_n == ref_n && memcmp(port_out, ref, ref_n) == 0, "port stream bytes do not depend on the input chunking",
              (int)port_n, (int)ref_n);
        stream_run(&kHostStream, COMPRESSION_STREAM_ENCODE, algorithm, input, n, chunk, 0, back, cap, &before_h, &first_h, &st_h);
        size_t slack = (progress_allowance(algorithm) + chunk - 1) / chunk * chunk;
        size_t gap = first_p > first_h ? first_p - first_h : first_h - first_p;
        check(first_h == NO_OUTPUT || (first_p != NO_OUTPUT && gap <= slack),
              "port writes output before FINALIZE where the host does, within the allowance", (int)first_p, (int)first_h);
        back_n = stream_run(&kHostStream, COMPRESSION_STREAM_DECODE, algorithm, port_out, port_n, chunk, 0, back, cap, &ignored, &ignored, &st_h);
        check(st_h == COMPRESSION_STATUS_END && back_n == n && (n == 0 || memcmp(back, input, n) == 0),
              "host decodes the port's stream", (int)back_n, (int)n);
        back_n = stream_run(&kPortStream, COMPRESSION_STREAM_DECODE, algorithm, host_out, host_n, chunk, 0, back, cap, &ignored, &ignored, &st_p);
        check(st_p == COMPRESSION_STATUS_END && back_n == n && (n == 0 || memcmp(back, input, n) == 0),
              "port stream decodes the host's stream", (int)back_n, (int)n);
        {
            size_t dbefore_h = 0, dbefore_p = 0, dfirst_h = NO_OUTPUT, dfirst_p = NO_OUTPUT;
            stream_run(&kHostStream, COMPRESSION_STREAM_DECODE, algorithm, host_out, host_n, chunk, 0, back, cap, &dbefore_h, &dfirst_h, &st_h);
            stream_run(&kPortStream, COMPRESSION_STREAM_DECODE, algorithm, host_out, host_n, chunk, 0, back, cap, &dbefore_p, &dfirst_p, &st_p);
            size_t dslack = (decode_allowance(algorithm) + chunk - 1) / chunk * chunk;
            size_t dgap = dfirst_p > dfirst_h ? dfirst_p - dfirst_h : dfirst_h - dfirst_p;
            check(dfirst_h == NO_OUTPUT || (dfirst_p != NO_OUTPUT && dgap <= dslack),
                  "port decodes the host's stream: output before FINALIZE within the allowance of the host's", (int)dfirst_p, (int)dfirst_h);
            size_t allow = decode_allowance(algorithm);
            check(dbefore_p + allow >= dbefore_h, "port decodes the host's stream: at least as much output before FINALIZE as the host, within the allowance",
                  (int)dbefore_p, (int)dbefore_h);
        }
    }
    snprintf(where, sizeof where, "%s n=%zu content=%d stream pieces=7", name_of(algorithm), n, content);
    port_n = stream_run(&kPortStream, COMPRESSION_STREAM_ENCODE, algorithm, input, n, all, 7, port_out, cap, &before_p, &first_p, &st_p);
    check(st_p == COMPRESSION_STATUS_END && port_n == ref_n && memcmp(port_out, ref, ref_n) == 0,
          "port stream output in 7-byte pieces equals its one-piece output and ends at FINALIZE", (int)port_n, (int)ref_n);
    back_n = stream_run(&kHostStream, COMPRESSION_STREAM_DECODE, algorithm, port_out, port_n, all, 7, back, cap, &ignored, &ignored, &st_h);
    check(st_h == COMPRESSION_STATUS_END && back_n == n && (n == 0 || memcmp(back, input, n) == 0),
          "host decodes the port's stream in 7-byte pieces", (int)back_n, (int)n);
    back_n = stream_run(&kPortStream, COMPRESSION_STREAM_DECODE, algorithm, host_out, host_n, all, 7, back, cap, &ignored, &ignored, &st_p);
    check(st_p == COMPRESSION_STATUS_END && back_n == n && (n == 0 || memcmp(back, input, n) == 0),
          "port stream decodes the host's stream in 7-byte pieces", (int)back_n, (int)n);
}

static void stream_all(uint8_t *input, uint8_t *host_out, uint8_t *port_out, uint8_t *ref, uint8_t *back, size_t cap)
{
    static const compression_algorithm kStreamAlgorithms[] = {COMPRESSION_LZFSE, COMPRESSION_ZLIB, COMPRESSION_LZ4, COMPRESSION_LZMA};
    for (size_t a = 0; a < sizeof kStreamAlgorithms / sizeof *kStreamAlgorithms; a++) {
        for (size_t s = 0; s < sizeof kSizes / sizeof *kSizes; s++) {
            for (int content = 0; content < kClasses; content++) {
                fill(input, kSizes[s], content);
                stream_checks(kStreamAlgorithms[a], content, input, kSizes[s], host_out, port_out, ref, back, cap);
            }
        }
        uint8_t junk[64];
        for (int i = 0; i < 64; i++) junk[i] = (uint8_t)next_random();
        size_t before_h, before_p, first_h, first_p;
        compression_status st_h, st_p;
        stream_run(&kHostStream, COMPRESSION_STREAM_DECODE, kStreamAlgorithms[a], junk, sizeof junk, sizeof junk, 0, back, cap, &before_h, &first_h, &st_h);
        stream_run(&kPortStream, COMPRESSION_STREAM_DECODE, kStreamAlgorithms[a], junk, sizeof junk, sizeof junk, 0, back, cap, &before_p, &first_p, &st_p);
        snprintf(where, sizeof where, "%s corrupt stream", name_of(kStreamAlgorithms[a]));
        check(st_p == st_h, "corrupt stream: the port answers the host's status", (int)st_p, (int)st_h);
    }
    compression_stream r;
    check(compression_stream_init(&r, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZ4_RAW) == COMPRESSION_STATUS_ERROR
          && charon_host_compression_stream_init(&r, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZ4_RAW) == COMPRESSION_STATUS_ERROR,
          "LZ4_RAW stream init: the port refuses what the host refuses", 0, 0);
}


struct lz4_seq { size_t tok, lit, lit_in, off_in, match, out_start, out_lit, out_end; int last; };

static size_t lz4_parse(const uint8_t *s, size_t len, struct lz4_seq *q)
{
    size_t in = 0, out = 0, k = 0;
    while (in < len) {
        struct lz4_seq *x = &q[k++];
        x->tok = in;
        x->out_start = out;
        uint8_t token = s[in++];
        size_t lit = token >> 4;
        if (lit == 15) {
            uint8_t b;
            do { b = s[in++]; lit += b; } while (b == 255);
        }
        x->lit = lit;
        x->lit_in = in;
        in += lit;
        out += lit;
        x->out_lit = out;
        x->off_in = in;
        x->match = 0;
        x->last = in == len;
        if (x->last) {
            x->out_end = out;
            break;
        }
        in += 2;
        size_t match = (token & 15) + 4;
        if ((token & 15) == 15) {
            uint8_t b;
            do { b = s[in++]; match += b; } while (b == 255);
        }
        x->match = match;
        out += match;
        x->out_end = out;
    }
    return k;
}

static void lz4_short(const uint8_t *block, size_t len, size_t n, size_t dst, uint8_t *back, void *host_work, void *port_work,
                      const char *what)
{
    size_t host_n = compression_decode_buffer(back, dst, block, len, host_work, COMPRESSION_LZ4_RAW);
    size_t port_n = charon_host_compression_decode_buffer(back, dst, block, len, port_work, COMPRESSION_LZ4_RAW);
    snprintf(where, sizeof where, "LZ4_RAW %s, n=%zu dst=%zu", what, n, dst);
    check(port_n == host_n, "a short decode destination of a cut or corrupt block", (int)port_n, (int)host_n);
}

static void lz4raw_cut_and_corrupt(const uint8_t *input, size_t n, size_t cap, void *encode_work, void *host_work, void *port_work,
                                   uint8_t *back)
{
    static const char *kEdits[] = {"as written", "offset 0", "offset beyond the output", "cut inside the literals",
                                   "cut inside the offset", "cut after the offset", "cut after the literals"};
    uint8_t *block = malloc(cap), *v = malloc(cap);
    size_t len = compression_encode_buffer(block, cap, input, n, encode_work, COMPRESSION_LZ4_RAW);
    struct lz4_seq *q = malloc(sizeof *q * (len / 2 + 2));
    size_t nseq = lz4_parse(block, len, q);
    size_t pick[4] = {0, nseq / 2, nseq >= 2 ? nseq - 2 : 0, nseq - 1};
    for (size_t p = 0; p < 4; p++) {
        struct lz4_seq *x = &q[pick[p]];
        for (int e = 0; e < 7; e++) {
            if (x->last && e != 0 && e != 3 && e != 6) continue;
            if (e == 3 && x->lit < 2) continue;
            size_t vlen = len;
            memcpy(v, block, len);
            switch (e) {
            case 1: v[x->off_in] = 0; v[x->off_in + 1] = 0; break;
            case 2: {
                size_t bad = x->out_lit + 1;
                v[x->off_in] = (uint8_t)bad;
                v[x->off_in + 1] = (uint8_t)(bad >> 8);
                break;
            }
            case 3: vlen = x->lit_in + x->lit / 2; break;
            case 4: vlen = x->off_in + 1; break;
            case 5: vlen = x->off_in + 2; break;
            case 6: vlen = x->lit_in + x->lit; break;
            default: break;
            }
            size_t cand[] = {x->out_start - (x->out_start > 0), x->out_start, x->out_start + 1, x->out_start + x->lit / 2,
                             x->out_lit - (x->out_lit > 0), x->out_lit, x->out_lit + 1, x->out_end - (x->out_end > 0),
                             x->out_end, x->out_end + 1, n - 1, n};
            char label[64];
            snprintf(label, sizeof label, "sequence %zu of %zu, %s", pick[p], nseq, kEdits[e]);
            for (size_t c = 0; c < sizeof cand / sizeof *cand; c++) {
                if (cand[c] > n) continue;
                lz4_short(v, vlen, n, cand[c], back, host_work, port_work, label);
            }
        }
    }
    free(block); free(v); free(q);
}

int main(int argc, char **argv)
{
    unsigned long long seed = argc > 1 ? strtoull(argv[1], NULL, 10) : 1;
    state = seed * 2654435761ULL + 1;
    printf("seed=%llu\n", seed);
    size_t cap = 300000 * 3 + 4096;
    uint8_t *input = malloc(300000), *packed = malloc(cap), *ours = malloc(cap), *back = malloc(cap), *nulls = malloc(cap);
    for (size_t a = 0; a < sizeof kAlgorithms / sizeof *kAlgorithms; a++) {
        compression_algorithm algorithm = kAlgorithms[a];
        size_t scratch_e = charon_host_compression_encode_scratch_buffer_size(algorithm);
        size_t scratch_d = charon_host_compression_decode_scratch_buffer_size(algorithm);
        size_t host_e = compression_encode_scratch_buffer_size(algorithm);
        size_t host_d = compression_decode_scratch_buffer_size(algorithm);
        printf("%s scratch encode host=%zu port=%zu decode host=%zu port=%zu\n", kNames[a], host_e, scratch_e, host_d, scratch_d);
        void *work_e = malloc(scratch_e ? scratch_e : 1), *work_d = malloc(scratch_d ? scratch_d : 1);
        void *host_work_e = malloc(host_e ? host_e : 1), *host_work_d = malloc(host_d ? host_d : 1);
        for (size_t s = 0; s < sizeof kSizes / sizeof *kSizes; s++) {
            size_t n = kSizes[s];
            for (int content = 0; content < kClasses; content++) {
                snprintf(where, sizeof where, "%s n=%zu content=%d", kNames[a], n, content);
                fill(input, n, content);
                size_t host_n = compression_encode_buffer(packed, cap, input, n, host_work_e, algorithm);
                size_t port_n = charon_host_compression_encode_buffer(ours, cap, input, n, work_e, algorithm);
                encoded_cases++;
                if (host_n) {
                    check(port_n != 0, "port encodes what the host encodes", (int)port_n, (int)host_n);
                    if (port_n) {
                        size_t decoded = charon_host_compression_decode_buffer(back, cap, packed, host_n, work_d, algorithm);
                        check(decoded == n && (n == 0 || memcmp(back, input, n) == 0), "port decodes the host's output", (int)decoded, (int)n);
                        size_t host_back = compression_decode_buffer(back, cap, ours, port_n, host_work_d, algorithm);
                        check(host_back == n && (n == 0 || memcmp(back, input, n) == 0), "host decodes the port's output", (int)host_back, (int)n);
                    }
                } else {
                    check(port_n == 0, "port answers 0 where the host does", (int)port_n, 0);
                }
                if (port_n && host_n && port_n == host_n && memcmp(ours, packed, port_n) == 0) equal_bytes[a]++;
                if (algorithm == COMPRESSION_LZMA && host_n) {
                    check(port_n == host_n && memcmp(ours, packed, host_n) == 0, "LZMA encodes the host's bytes", (int)port_n, (int)host_n);
                }
                size_t null_host = compression_encode_buffer(nulls, cap, input, n, NULL, algorithm);
                size_t null_port = charon_host_compression_encode_buffer(ours, cap, input, n, NULL, algorithm);
                check((null_port != 0) == (null_host != 0), "NULL scratch: port encodes when the host does", (int)null_port, (int)null_host);
                if (null_port) {
                    size_t null_back = charon_host_compression_decode_buffer(back, cap, ours, null_port, NULL, algorithm);
                    check(null_back == n && (n == 0 || memcmp(back, input, n) == 0), "NULL scratch: port decodes its output", (int)null_back, (int)n);
                }
                if (host_n) {
                    size_t null_back = charon_host_compression_decode_buffer(back, cap, packed, host_n, NULL, algorithm);
                    check(null_back == n && (n == 0 || memcmp(back, input, n) == 0), "NULL scratch: port decodes the host's output", (int)null_back, (int)n);
                }
                if (port_n) {
                    size_t fit = charon_host_compression_encode_buffer(ours, port_n, input, n, work_e, algorithm);
                    check(fit == port_n, "port encode fits its own size", (int)fit, (int)port_n);
                    size_t short_port = charon_host_compression_encode_buffer(ours, port_n - 1, input, n, work_e, algorithm);
                    check(short_port == 0 || short_port < port_n && decodes(short_port, ours, n, input, back, cap, host_work_d, algorithm),
                          "port encode one byte short", (int)short_port, 0);
                }
                if (host_n) {
                    size_t short_host = compression_encode_buffer(packed, host_n - 1, input, n, host_work_e, algorithm);
                    check(short_host == 0 || short_host < host_n && decodes(short_host, packed, n, input, back, cap, host_work_d, algorithm),
                          "host encode one byte short", (int)short_host, 0);
                    size_t step = host_n <= 8192 ? 1 : host_n / 97 + 1;
                    for (size_t k = 0; k < host_n; k += step) {
                        snprintf(where, sizeof where, "%s n=%zu content=%d truncated=%zu", kNames[a], n, content, k);
                        size_t trunc_host = compression_decode_buffer(back, cap, packed, k, host_work_d, algorithm);
                        size_t trunc_port = charon_host_compression_decode_buffer(back, cap, packed, k, work_d, algorithm);
                        check_known(trunc_port == trunc_host, kKnownZLIBTruncation,
                                    algorithm == COMPRESSION_ZLIB && trunc_port == 0 && trunc_host != 0,
                                    "a truncated stream", (int)trunc_port, (int)trunc_host);
                    }
                    snprintf(where, sizeof where, "%s n=%zu content=%d", kNames[a], n, content);
                }
                if (n > 0 && host_n) {
                    size_t dsts[] = {0, 1, n / 3, n / 2, n - 1};
                    for (size_t d = 0; d < sizeof dsts / sizeof *dsts; d++) {
                        size_t small_host = compression_decode_buffer(back, dsts[d], packed, host_n, host_work_d, algorithm);
                        size_t small_port = charon_host_compression_decode_buffer(back, dsts[d], packed, host_n, work_d, algorithm);
                        check(small_port == small_host, "a short decode destination", (int)small_port, (int)small_host);
                    }
                }
                if (algorithm == COMPRESSION_LZ4_RAW && content == 3 && n >= 4096 && host_n) {
                    lz4raw_cut_and_corrupt(input, n, cap, host_work_e, host_work_d, work_d, back);
                }
            }
        }
        uint8_t junk[64];
        for (int i = 0; i < 64; i++) junk[i] = (uint8_t)next_random();
        size_t junk_host = compression_decode_buffer(back, cap, junk, sizeof junk, host_work_d, algorithm);
        size_t junk_port = charon_host_compression_decode_buffer(back, cap, junk, sizeof junk, work_d, algorithm);
        check(junk_port == junk_host, "corrupt input", (int)junk_port, (int)junk_host);
        size_t unknown_host = compression_encode_buffer(packed, cap, input, 4, host_work_e, (compression_algorithm)0xFFF);
        size_t unknown_port = charon_host_compression_encode_buffer(ours, cap, input, 4, work_e, (compression_algorithm)0xFFF);
        check(unknown_host == 0 && unknown_port == 0, "unknown algorithm", (int)unknown_port, (int)unknown_host);
        free(work_e); free(work_d); free(host_work_e); free(host_work_d);
    }
    stream_all(input, packed, ours, nulls, back, cap);
    for (size_t a = 0; a < sizeof kAlgorithms / sizeof *kAlgorithms; a++) {
        int per_algorithm = (int)(sizeof kSizes / sizeof *kSizes) * kClasses;
        printf("%s encode: port bytes equal the host's in %d of %d cases (%s)\n", kNames[a], equal_bytes[a], per_algorithm,
               kAlgorithms[a] == COMPRESSION_LZMA ? "required" : "reported, not required");
    }
    printf("encode cases=%d\n", encoded_cases);
    for (int row = 0; row < kKnownRows; row++) printf("KNOWN-DIFF [%s]: %d checks differ from the host, as the entry says\n", kKnownNames[row], known[row]);
    int known_total = 0;
    for (int row = 0; row < kKnownRows; row++) known_total += known[row];
    printf("checks=%d failures=%d known-diff=%d\n", checks, failures, known_total);
    return failures ? 1 : 0;
}
