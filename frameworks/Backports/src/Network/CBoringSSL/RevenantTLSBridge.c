#include <dlfcn.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static const char RevenantSecurityBackportPath[] = "/usr/lib/revenant/org.revenant.backports/libSecurityBackports.dylib";

static id RevenantSend(const void *receiver, const char *selector)
{
    return ((id (*)(id, SEL))objc_msgSend)((id)receiver, sel_registerName(selector));
}

static bool RevenantSendBool(const void *receiver, const char *selector)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)((id)receiver, sel_registerName(selector)) != NO;
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
    if (!cls) {
        dlopen(RevenantSecurityBackportPath, RTLD_NOW | RTLD_GLOBAL);
        cls = objc_getClass("RevenantSecProtocolOptions");
    }
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
    return RevenantSendBool(options, "peerAuthenticationRequired");
}

bool RevenantSecProtocolOptionsOCSPEnabled(const void *options)
{
    return RevenantSendBool(options, "ocspEnabled");
}

bool RevenantSecProtocolOptionsSCTEnabled(const void *options)
{
    return RevenantSendBool(options, "sctEnabled");
}

bool RevenantSecProtocolOptionsHasVerifyBlock(const void *options)
{
    return RevenantSend(options, "verifyBlock") != nil;
}

bool RevenantSecProtocolOptionsHasChallengeBlock(const void *options)
{
    return RevenantSend(options, "challengeBlock") != nil;
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

size_t RevenantSecProtocolOptionsCiphersuiteCount(const void *options)
{
    id suites = RevenantSend(options, "ciphersuites");
    return ((unsigned long (*)(id, SEL))objc_msgSend)(suites, sel_registerName("count"));
}

uint32_t RevenantSecProtocolOptionsCiphersuiteAt(const void *options, size_t index)
{
    id suites = RevenantSend(options, "ciphersuites");
    id value = ((id (*)(id, SEL, unsigned long))objc_msgSend)(suites, sel_registerName("objectAtIndex:"), (unsigned long)index);
    return ((unsigned int (*)(id, SEL))objc_msgSend)(value, sel_registerName("unsignedIntValue"));
}

const void *RevenantSecProtocolOptionsCopyLocalIdentity(const void *options)
{
    return RevenantSend(options, "revenantCopyIdentityRef");
}

const void *RevenantSecProtocolOptionsCopyChallengeIdentity(const void *options)
{
    return ((const void *(*)(id, SEL))objc_msgSend)((id)options, sel_registerName("revenantChallengeIdentity"));
}

bool RevenantSecProtocolOptionsVerifyTrust(const void *options, const void *trust)
{
    return ((BOOL (*)(id, SEL, const void *))objc_msgSend)((id)options, sel_registerName("revenantVerifyTrust:"), trust) != NO;
}

const char *RevenantSecProtocolOptionsUnsupportedSetting(const void *options, bool serverSide)
{
    return ((const char *(*)(id, SEL, BOOL))objc_msgSend)((id)options, sel_registerName("revenantUnsupportedSettingForServer:"), serverSide ? YES : NO);
}
