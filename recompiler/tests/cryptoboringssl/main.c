#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#include <CCryptoBoringSSL_aead.h>
#include <CCryptoBoringSSL_sha.h>

extern uint32_t CCryptoBoringSSL_OPENSSL_get_armcap(void);

enum { LONG_SIZE = 1000 };

static int failures;

static void hex(const uint8_t *bytes, size_t size, char *out) {
    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < size; i++) {
        out[2 * i] = digits[bytes[i] >> 4];
        out[2 * i + 1] = digits[bytes[i] & 15];
    }
    out[2 * size] = 0;
}

static void expect(const char *name, const uint8_t *bytes, size_t size, const char *want) {
    char got[2 * (LONG_SIZE + 16) + 1];
    hex(bytes, size, got);
    int ok = strcmp(got, want) == 0;
    failures += !ok;
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
    if (!ok) {
        printf("  want %s\n  got  %s\n", want, got);
    }
    fflush(stdout);
}

static void check(const char *name, int ok) {
    failures += !ok;
    printf("%s %s\n", ok ? "ok" : "FAIL", name);
    fflush(stdout);
}

typedef struct {
    const char *name;
    const EVP_AEAD *aead;
    const uint8_t *key;
    size_t key_size;
    const uint8_t *nonce;
    const uint8_t *aad;
    size_t aad_size;
    const uint8_t *message;
    size_t size;
    const char *want_ciphertext;
    const char *want_tag;
} Vector;

static const uint8_t zero_key[32], zero_nonce[12];

static void seal_open(const Vector *vector) {
    uint8_t sealed[LONG_SIZE + 16], opened[LONG_SIZE], wrong_aad[16];
    size_t sealed_size = 0, opened_size = 0;
    size_t size = vector->size, aad_size = vector->aad_size;
    EVP_AEAD_CTX context;
    char label[96];
    EVP_AEAD_CTX_zero(&context);
    check("aead init", EVP_AEAD_CTX_init(&context, vector->aead, vector->key, vector->key_size, 16, NULL));
    check("aead seal", EVP_AEAD_CTX_seal(&context, sealed, &sealed_size, sizeof(sealed), vector->nonce, 12, vector->message, size, vector->aad, aad_size));
    snprintf(label, sizeof(label), "%s ciphertext", vector->name);
    expect(label, sealed, strlen(vector->want_ciphertext) / 2, vector->want_ciphertext);
    snprintf(label, sizeof(label), "%s tag", vector->name);
    expect(label, sealed + size, 16, vector->want_tag);
    snprintf(label, sizeof(label), "%s open", vector->name);
    check(label, EVP_AEAD_CTX_open(&context, opened, &opened_size, sizeof(opened), vector->nonce, 12, sealed, sealed_size, vector->aad, aad_size)
                     && opened_size == size && memcmp(opened, vector->message, size) == 0);
    if (aad_size) {
        memcpy(wrong_aad, vector->aad, aad_size);
        wrong_aad[0] ^= 1;
        snprintf(label, sizeof(label), "%s wrong aad", vector->name);
        check(label, !EVP_AEAD_CTX_open(&context, opened, &opened_size, sizeof(opened), vector->nonce, 12, sealed, sealed_size, wrong_aad, aad_size));
    }
    sealed[sealed_size - 1] ^= 1;
    snprintf(label, sizeof(label), "%s tamper", vector->name);
    check(label, !EVP_AEAD_CTX_open(&context, opened, &opened_size, sizeof(opened), vector->nonce, 12, sealed, sealed_size, vector->aad, aad_size));
    EVP_AEAD_CTX_cleanup(&context);
}

enum { CHUNK = 16384, ROUNDS = 16 };

static uint8_t big_message[CHUNK], big_sealed[CHUNK + 16];

static double now_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec * 1e9 + (double)tv.tv_usec * 1e3;
}

static double megabytes_per_second(double nanoseconds) {
    return CHUNK * (double)ROUNDS / nanoseconds * 1e3;
}

static double time_seal(const EVP_AEAD *aead) {
    size_t sealed_size = 0;
    EVP_AEAD_CTX context;
    EVP_AEAD_CTX_zero(&context);
    EVP_AEAD_CTX_init(&context, aead, zero_key, sizeof(zero_key), 16, NULL);
    double start = now_ns();
    for (unsigned i = 0; i < ROUNDS; i++) {
        EVP_AEAD_CTX_seal(&context, big_sealed, &sealed_size, sizeof(big_sealed), zero_nonce, sizeof(zero_nonce), big_message, CHUNK, NULL, 0);
    }
    double elapsed = now_ns() - start;
    EVP_AEAD_CTX_cleanup(&context);
    return megabytes_per_second(elapsed);
}

static void time_throughput(void) {
    uint8_t digest[32];
    double start = now_ns();
    for (unsigned i = 0; i < ROUNDS; i++) {
        SHA256(big_message, CHUNK, digest);
    }
    double sha = megabytes_per_second(now_ns() - start);
    double gcm = time_seal(EVP_aead_aes_256_gcm());
    double chacha = time_seal(EVP_aead_chacha20_poly1305());
    printf("time sha256 %.2f MB/s, aes-256-gcm seal %.2f MB/s, chacha20-poly1305 seal %.2f MB/s (check %02x%02x)\n", sha, gcm, chacha, digest[0],
           big_sealed[0]);
    fflush(stdout);
}

static const uint8_t rfc8439_key[32] = {0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
                                        0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f};
static const uint8_t rfc8439_nonce[12] = {0x07, 0x00, 0x00, 0x00, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47};
static const uint8_t rfc8439_aad[12] = {0x50, 0x51, 0x52, 0x53, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7};
static const char rfc8439_message[] = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";

int main(void) {
    uint8_t digest[32], message[LONG_SIZE], zero[16] = {0};
    for (unsigned i = 0; i < LONG_SIZE; i++) {
        message[i] = (uint8_t)(i * 7);
    }
    printf("armcap %08x\n", (unsigned)CCryptoBoringSSL_OPENSSL_get_armcap());
    fflush(stdout);
    SHA256((const uint8_t *)"abc", 3, digest);
    expect("sha256 abc", digest, 32, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    SHA256(message, LONG_SIZE, digest);
    expect("sha256 1000 bytes", digest, 32, "89f4ff56a25dd1db06a4ce6033603775d705fb96f30f8693733fef602a1ca532");
    SHA1((const uint8_t *)"abc", 3, digest);
    expect("sha1 abc", digest, 20, "a9993e364706816aba3e25717850c26c9cd0d89d");
    seal_open(&(Vector){"aes-128-gcm 16 zero bytes", EVP_aead_aes_128_gcm(), zero_key, 16, zero_nonce, NULL, 0, zero, 16,
                        "0388dace60b6a392f328c2b971b2fe78", "ab6e47d42cec13bdf53a67b21257bddf"});
    seal_open(&(Vector){"aes-256-gcm 16 zero bytes", EVP_aead_aes_256_gcm(), zero_key, 32, zero_nonce, NULL, 0, zero, 16,
                        "cea7403d4d606b6e074ec5d3baf39d18", "d0d1c8a799996bf0265b98b5d48ab919"});
    seal_open(&(Vector){"aes-256-gcm 1000 bytes", EVP_aead_aes_256_gcm(), zero_key, 32, zero_nonce, NULL, 0, message, LONG_SIZE,
                        "cea04e285143415f3f71839eeea8ff71", "719fde13fab297855213cae010422fe1"});
    seal_open(&(Vector){"chacha20-poly1305 rfc 8439", EVP_aead_chacha20_poly1305(), rfc8439_key, 32, rfc8439_nonce, rfc8439_aad, sizeof(rfc8439_aad),
                        (const uint8_t *)rfc8439_message, sizeof(rfc8439_message) - 1,
                        "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36"
                        "92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116",
                        "1ae10b594f09e26a7e902ecbd0600691"});
    seal_open(&(Vector){"chacha20-poly1305 16 zero bytes", EVP_aead_chacha20_poly1305(), zero_key, 32, zero_nonce, NULL, 0, zero, 16,
                        "9f07e7be5551387a98ba977c732d080d", "c34a88047320f52aa2c6683ef8084d2f"});
    seal_open(&(Vector){"chacha20-poly1305 1000 bytes", EVP_aead_chacha20_poly1305(), zero_key, 32, zero_nonce, NULL, 0, message, LONG_SIZE,
                        "9f00e9ab4972124ba085d13127766a64", "4be18cd706ff902db998ecf0ecfcc49b"});
    time_throughput();
    printf("done failures=%d\n", failures);
    return failures != 0;
}
