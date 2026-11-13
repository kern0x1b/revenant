#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>

#include <CCryptoBoringSSL_aead.h>
#include <CCryptoBoringSSL_sha.h>

extern uint32_t CCryptoBoringSSL_OPENSSL_get_armcap(void);

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
    char got[2 * 64 + 1];
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

enum { LONG_SIZE = 1000 };

static void seal_open(const char *name, const EVP_AEAD *aead, size_t key_size, const uint8_t *message, size_t size,
                      const char *want_prefix, const char *want_tag) {
    uint8_t key[32] = {0}, nonce[12] = {0}, sealed[LONG_SIZE + 16], opened[LONG_SIZE];
    size_t sealed_size = 0, opened_size = 0;
    EVP_AEAD_CTX context;
    char label[96];
    EVP_AEAD_CTX_zero(&context);
    check("aead init", EVP_AEAD_CTX_init(&context, aead, key, key_size, 16, NULL));
    check("aead seal", EVP_AEAD_CTX_seal(&context, sealed, &sealed_size, sizeof(sealed), nonce, sizeof(nonce), message, size, NULL, 0));
    snprintf(label, sizeof(label), "%s ciphertext", name);
    expect(label, sealed, 16, want_prefix);
    snprintf(label, sizeof(label), "%s tag", name);
    expect(label, sealed + size, 16, want_tag);
    snprintf(label, sizeof(label), "%s open", name);
    check(label, EVP_AEAD_CTX_open(&context, opened, &opened_size, sizeof(opened), nonce, sizeof(nonce), sealed, sealed_size, NULL, 0)
                     && opened_size == size && memcmp(opened, message, size) == 0);
    sealed[sealed_size - 1] ^= 1;
    snprintf(label, sizeof(label), "%s tamper", name);
    check(label, !EVP_AEAD_CTX_open(&context, opened, &opened_size, sizeof(opened), nonce, sizeof(nonce), sealed, sealed_size, NULL, 0));
    EVP_AEAD_CTX_cleanup(&context);
}

enum { CHUNK = 16384, ROUNDS = 16 };

static uint8_t big_message[CHUNK], big_sealed[CHUNK + 16];

static double now_ns(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double)tv.tv_sec * 1e9 + (double)tv.tv_usec * 1e3;
}

static void time_throughput(const EVP_AEAD *aead) {
    uint8_t key[32] = {0}, nonce[12] = {0}, digest[32];
    size_t sealed_size = 0;
    EVP_AEAD_CTX context;
    EVP_AEAD_CTX_zero(&context);
    EVP_AEAD_CTX_init(&context, aead, key, sizeof(key), 16, NULL);
    double start = now_ns();
    for (unsigned i = 0; i < ROUNDS; i++) {
        SHA256(big_message, CHUNK, digest);
    }
    double sha = now_ns() - start;
    start = now_ns();
    for (unsigned i = 0; i < ROUNDS; i++) {
        EVP_AEAD_CTX_seal(&context, big_sealed, &sealed_size, sizeof(big_sealed), nonce, sizeof(nonce), big_message, CHUNK, NULL, 0);
    }
    double seal = now_ns() - start;
    EVP_AEAD_CTX_cleanup(&context);
    printf("time sha256 %.2f MB/s, aes-256-gcm seal %.2f MB/s (check %02x%02x)\n", CHUNK * (double)ROUNDS / sha * 1e3, CHUNK * (double)ROUNDS / seal * 1e3,
           digest[0], big_sealed[0]);
    fflush(stdout);
}

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
    seal_open("aes-128-gcm 16 zero bytes", EVP_aead_aes_128_gcm(), 16, zero, 16, "0388dace60b6a392f328c2b971b2fe78", "ab6e47d42cec13bdf53a67b21257bddf");
    seal_open("aes-256-gcm 16 zero bytes", EVP_aead_aes_256_gcm(), 32, zero, 16, "cea7403d4d606b6e074ec5d3baf39d18", "d0d1c8a799996bf0265b98b5d48ab919");
    seal_open("aes-256-gcm 1000 bytes", EVP_aead_aes_256_gcm(), 32, message, LONG_SIZE, "cea04e285143415f3f71839eeea8ff71", "719fde13fab297855213cae010422fe1");
    time_throughput(EVP_aead_aes_256_gcm());
    printf("done failures=%d\n", failures);
    return failures != 0;
}
