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

    ptls_cipher_suite_t *client_cipher = ptls_get_cipher(client);
    ptls_cipher_suite_t *server_cipher = ptls_get_cipher(server);
    check(client_cipher != NULL && ((client_cipher->id >> 8) & 0xff) == 0x13,
          "what the client negotiated is a TLS 1.3 cipher suite");
    check(server_cipher != NULL && server_cipher->id == client_cipher->id,
          "and both sides negotiated the same one");

    const char *message = "ping";
    if (ptls_send(client, &client_writes, message, strlen(message)) != 0) {
        check(0, "the client sent application data");
    } else {
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
