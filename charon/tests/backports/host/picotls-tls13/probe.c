/*
 * One TLS 1.3 handshake between a picotls client and a picotls server, to prove the stack the port
 * builds for a QUIC handshake is usable on this release.
 *
 * The port's own SecureTransport stops at TLS 1.1 on iOS 6.1.3 - measured: that release exports
 * SSLContextCreate and not SSLSetProtocolVersion - so the TLS 1.3 a QUIC handshake needs has to come
 * from picotls with its own crypto. The pump is the one picotls's own t/minicrypto.c:test_hrr uses:
 * each side writes into its own buffer, and each buffer is handed to the other side's
 * ptls_handshake, which is what a socket carries between them. What this proves is the handshake and
 * the record layer: both sides report it done, what was negotiated is a TLS 1.3 cipher suite, and
 * application data the client sends arrives at the server.
 *
 * The certificate is the probe's own and the key with it, both read from files the run script makes
 * with the host's own openssl, so the port's tree holds neither. Nothing is verified - picotls-minicrypto
 * has no X.509 verifier, which is the one thing a port has to answer for itself
 * (facts/Network/NWQUIC.md), and a probe that skipped verification to show a handshake is not a probe
 * that would show trust.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <picotls.h>
#include <picotls/minicrypto.h>

static int failures, checks_run;

static void check(int condition, const char *what)
{
    checks_run++;
    if (condition) {
        printf("ok %s\n", what);
    } else {
        printf("FAIL %s\n", what);
        failures++;
    }
}

/* One flight: this side writes what it has to say, and takes in what the other wrote. */
static int flight(ptls_t *tls, ptls_buffer_t *out, const void *in, size_t inlen)
{
    size_t consumed = inlen;
    int result = ptls_handshake(tls, out, in, inlen ? &consumed : NULL, NULL);
    return result;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s CERTIFICATE.pem PRIVATE_KEY.raw\n", argv[0]);
        return 2;
    }
    FILE *certificate_file = fopen(argv[1], "rb");
    if (!certificate_file) {
        fprintf(stderr, "cannot read the certificate %s\n", argv[1]);
        return 2;
    }
    static uint8_t certificate_bytes[8192];
    size_t certificate_length = fread(certificate_bytes, 1, sizeof certificate_bytes, certificate_file);
    fclose(certificate_file);

    /* The key is the raw secp256r1 scalar, which is what picotls's own signer takes. */
    static uint8_t key_bytes[32];
    FILE *key_file = fopen(argv[2], "rb");
    if (!key_file) {
        fprintf(stderr, "cannot read the private key %s\n", argv[2]);
        return 2;
    }
    size_t key_length = fread(key_bytes, 1, sizeof key_bytes, key_file);
    fclose(key_file);
    if (key_length != sizeof key_bytes) {
        fprintf(stderr, "the private key is %zu bytes, not %zu\n", key_length, sizeof key_bytes);
        return 2;
    }

    ptls_context_t context;
    memset(&context, 0, sizeof context);
    context.random_bytes = ptls_minicrypto_random_bytes;
    context.get_time = &ptls_get_time;
    context.key_exchanges = ptls_minicrypto_key_exchanges;
    context.cipher_suites = ptls_minicrypto_cipher_suites_all;
    ptls_iovec_t certificate = ptls_iovec_init(certificate_bytes, certificate_length);
    context.certificates.list = &certificate;
    context.certificates.count = 1;
    /* The server's signature over the handshake, and with it the private key of the certificate. The
       client's own check of that signature is a verify_certificate callback, and there is none here on
       purpose (see the header of this file). */
    ptls_minicrypto_secp256r1sha256_sign_certificate_t signer;
    ptls_minicrypto_init_secp256r1sha256_sign_certificate(&signer, ptls_iovec_init(key_bytes, sizeof key_bytes));
    context.sign_certificate = &signer.super;

    ptls_t *client = ptls_new(&context, 0);
    ptls_t *server = ptls_new(&context, 1);
    check(client != NULL && server != NULL, "both contexts are made");

    uint8_t storage[4][16384];
    ptls_buffer_t client_writes, server_writes, received;
    ptls_buffer_init(&client_writes, storage[0], sizeof storage[0]);
    ptls_buffer_init(&server_writes, storage[1], sizeof storage[1]);
    ptls_buffer_init(&received, storage[2], sizeof storage[2]);

    int client_done = 0, server_done = 0, result = 0;
    for (int round = 0; round < 12 && !(client_done && server_done); round++) {
        if (!client_done) {
            const void *in = server_writes.off ? server_writes.base : NULL;
            size_t inlen = server_writes.off;
            result = flight(client, &client_writes, in, inlen);
            if (result == 0) {
                client_done = 1;
            } else if (result != PTLS_ERROR_IN_PROGRESS) {
                printf("  the client stopped with %d\n", result);
                break;
            }
            if (inlen)
                server_writes.off = 0;
        }
        if (!server_done) {
            const void *in = client_writes.off ? client_writes.base : NULL;
            size_t inlen = client_writes.off;
            result = flight(server, &server_writes, in, inlen);
            if (result == 0) {
                server_done = 1;
            } else if (result != PTLS_ERROR_IN_PROGRESS) {
                printf("  the server stopped with %d\n", result);
                break;
            }
            if (inlen)
                client_writes.off = 0;
        }
    }
    check(client_done && server_done, "the handshake completed on both sides");
    if (!client_done || !server_done) {
        printf("  the client wrote %zu bytes, the server %zu\n", client_writes.off, server_writes.off);
        return 1;
    }

    /* What was negotiated, read off the cipher suite both sides picked: a TLS 1.3 suite's second
       byte is 0x13, which is the only place the version shows in a 1.3 record. */
    ptls_cipher_suite_t *client_cipher = ptls_get_cipher(client);
    ptls_cipher_suite_t *server_cipher = ptls_get_cipher(server);
    check(client_cipher != NULL && ((client_cipher->id >> 8) & 0xff) == 0x13,
          "what the client negotiated is a TLS 1.3 cipher suite");
    check(server_cipher != NULL && server_cipher->id == client_cipher->id,
          "and both sides negotiated the same one");

    /* Application data, the reason any of this is here. */
    const char *message = "ping";
    if (ptls_send(client, &client_writes, message, strlen(message)) != 0) {
        check(0, "the client sent application data");
    } else {
        /* ptls_receive decrypts one record and answers 0 for each of them: what the record held is in
           the plaintext buffer, and a record can be a session ticket rather than what this is looking
           for, so the records are read until the message is among them. */
        size_t offset = 0, total = client_writes.off, found = 0;
        ptls_buffer_init(&received, storage[2], sizeof storage[2]);
        for (int record = 0; record < 8 && offset < total; record++) {
            size_t inlen = total - offset;
            int result = ptls_receive(server, &received, client_writes.base + offset, &inlen);
            offset += inlen;
            if (result != 0) {
                printf("  a record was not accepted: %d\n", result);
                break;
            }
            if (received.off >= strlen(message) &&
                memcmp(received.base + received.off - strlen(message), message, strlen(message)) == 0) {
                found = received.off;
                break;
            }
        }
        check(found != 0, "and the server read it back");
    }

    ptls_free(client);
    ptls_free(server);
    printf("checks=%d failures=%d\n", checks_run, failures);
    return failures ? 1 : 0;
}
