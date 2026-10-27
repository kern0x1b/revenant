#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static id RevenantSend(const void *receiver, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)((id)receiver, sel_registerName(selector));
}

static const char *RevenantUTF8(id string)
{
    if (!string)
        return NULL;
    return ((const char *(*)(id, SEL))objc_msgSend)(string, sel_registerName("UTF8String"));
}

void *RevenantSecProtocolOptionsCreate(void)
{
    Class cls = objc_getClass("RevenantSecProtocolOptions");
    if (!cls)
        return NULL;
    id allocated = ((id (*)(id, SEL))objc_msgSend)((id)cls, sel_registerName("alloc"));
    return ((id (*)(id, SEL))objc_msgSend)(allocated, sel_registerName("init"));
}

uint16_t RevenantSecProtocolOptionsMinTLS(const void *options)
{
    return ((uint16_t (*)(id, SEL))objc_msgSend)((id)options, sel_registerName("minTLSVersion"));
}

uint16_t RevenantSecProtocolOptionsMaxTLS(const void *options)
{
    return ((uint16_t (*)(id, SEL))objc_msgSend)((id)options, sel_registerName("maxTLSVersion"));
}

bool RevenantSecProtocolOptionsPeerAuthenticationRequired(const void *options)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)((id)options, sel_registerName("peerAuthenticationRequired")) != NO;
}

const char *RevenantSecProtocolOptionsServerName(const void *options)
{
    return RevenantUTF8(RevenantSend(options, "serverName"));
}

size_t RevenantSecProtocolOptionsApplicationProtocolCount(const void *options)
{
    id protocols = RevenantSend(options, "applicationProtocols");
    return ((unsigned long (*)(id, SEL))objc_msgSend)(protocols, sel_registerName("count"));
}

const char *RevenantSecProtocolOptionsApplicationProtocolAt(const void *options, size_t index)
{
    id protocols = RevenantSend(options, "applicationProtocols");
    id name = ((id (*)(id, SEL, unsigned long))objc_msgSend)(protocols, sel_registerName("objectAtIndex:"), (unsigned long)index);
    return RevenantUTF8(name);
}

const void *RevenantSecProtocolOptionsCopyLocalIdentity(const void *options)
{
    return RevenantSend(options, "revenantCopyIdentityRef");
}
