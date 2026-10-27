#ifndef REVENANT_TLS_ENGINE_H
#define REVENANT_TLS_ENGINE_H

#include <Security/SecBase.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define REVENANT_TLS_EXPORT __attribute__((visibility("default")))

typedef struct RevenantTLSEngine RevenantTLSEngine;

REVENANT_TLS_EXPORT void *RevenantTLSOptionsCreate(void);
REVENANT_TLS_EXPORT bool RevenantTLSOptionsHasServerCredentials(const void *options);

REVENANT_TLS_EXPORT RevenantTLSEngine *RevenantTLSEngineCreate(const void *options, int descriptor,
                                                               const char *defaultServerName, bool serverSide,
                                                               char *reason, size_t reasonCapacity,
                                                               OSStatus *status);
REVENANT_TLS_EXPORT void RevenantTLSEngineFree(RevenantTLSEngine *engine);

REVENANT_TLS_EXPORT OSStatus RevenantTLSEngineHandshake(RevenantTLSEngine *engine);
REVENANT_TLS_EXPORT OSStatus RevenantTLSEngineRead(RevenantTLSEngine *engine, void *buffer, size_t capacity,
                                                   size_t *count);
REVENANT_TLS_EXPORT OSStatus RevenantTLSEngineWrite(RevenantTLSEngine *engine, const void *bytes, size_t count,
                                                    size_t *written);
REVENANT_TLS_EXPORT void RevenantTLSEngineClose(RevenantTLSEngine *engine);

REVENANT_TLS_EXPORT bool RevenantTLSEngineIsEstablished(const RevenantTLSEngine *engine);
REVENANT_TLS_EXPORT bool RevenantTLSEngineWantsWrite(const RevenantTLSEngine *engine);
REVENANT_TLS_EXPORT uint16_t RevenantTLSEngineNegotiatedVersion(const RevenantTLSEngine *engine);
REVENANT_TLS_EXPORT uint16_t RevenantTLSEngineNegotiatedCipherSuite(const RevenantTLSEngine *engine);
REVENANT_TLS_EXPORT const uint8_t *RevenantTLSEngineNegotiatedProtocol(const RevenantTLSEngine *engine,
                                                                       size_t *length);
REVENANT_TLS_EXPORT const uint8_t *RevenantTLSEngineOCSPResponse(const RevenantTLSEngine *engine, size_t *length);

#endif
