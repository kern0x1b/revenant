#pragma once

struct dispatch_source_type_s;
#ifdef __cplusplus
extern "C" {
#endif
extern const struct dispatch_source_type_s _dispatch_source_type_vm;
#ifdef __cplusplus
}
#endif

#ifndef HAVE_XPC_API
#define HAVE_XPC_API 0
#endif

#ifndef HAVE_OS_SIGNPOST
#define HAVE_OS_SIGNPOST 0
#endif

#include <mach/vm_statistics.h>
#undef VM_FLAGS_PERMANENT
#define VM_FLAGS_PERMANENT 0

#include <stdint.h>
#ifndef WEBKIT_IOS6_CMTAG_STUBS
#define WEBKIT_IOS6_CMTAG_STUBS
typedef uint32_t CMTagCategory;
typedef struct OpaqueCMTagCollection *CMTagCollectionRef;
typedef struct OpaqueCMTaggedBufferGroup *CMTaggedBufferGroupRef;
typedef struct OpaqueCMTaggedBufferGroupFormatDescription *CMTaggedBufferGroupFormatDescriptionRef;
typedef struct { uint64_t value[2]; } CMTag;
#endif

#include <mach/port.h>
#ifndef WEBKIT_IOS6_TASK_ID_TOKEN
#define WEBKIT_IOS6_TASK_ID_TOKEN
typedef mach_port_t task_id_token_t;
#endif
#if defined(__OBJC__)
#define UIUserInterfaceIdiomVision ((UIUserInterfaceIdiom)6)
#endif


#if defined(__cplusplus)
#include <pthread.h>
#include <stdint.h>
template<typename T> class IOS6ThreadLocal {
public:
    operator T() const { return unpack(pthread_getspecific(key())); }
    IOS6ThreadLocal& operator=(T value) { pthread_setspecific(key(), pack(value)); return *this; }
    T operator->() const { return unpack(pthread_getspecific(key())); }
    bool operator!() const { return !static_cast<T>(*this); }
    T operator++() { T value = static_cast<T>(*this) + 1; *this = value; return value; }
    T operator--() { T value = static_cast<T>(*this) - 1; *this = value; return value; }

private:
    static T unpack(void* slot) { return (T)(uintptr_t)slot; }
    static void* pack(T value) { return (void*)(uintptr_t)value; }

    pthread_key_t key() const
    {
        uintptr_t stored = __atomic_load_n(&m_keyPlusOne, __ATOMIC_ACQUIRE);
        if (!stored) {
            pthread_key_t fresh;
            pthread_key_create(&fresh, nullptr);
            uintptr_t expected = 0;
            uintptr_t desired = static_cast<uintptr_t>(fresh) + 1;
            if (__atomic_compare_exchange_n(&m_keyPlusOne, &expected, desired, false,
                                            __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE))
                stored = desired;
            else {
                pthread_key_delete(fresh);
                stored = expected;
            }
        }
        return static_cast<pthread_key_t>(stored - 1);
    }

    mutable uintptr_t m_keyPlusOne = 0;
};
#endif

#if defined(__OBJC__)
#ifndef AXCustomContentImportanceHigh
#define AXCustomContentImportanceHigh 1
#endif
#endif

#if defined(__OBJC__)
#import <Foundation/Foundation.h>
#ifndef WEBKIT_IOS6_TEXT_LIST
#define WEBKIT_IOS6_TEXT_LIST
typedef NSString *NSTextListMarkerFormat;
@interface NSTextList : NSObject
@property (readonly, copy) NSTextListMarkerFormat markerFormat;
@property NSInteger startingItemNumber;
@end
#endif
#endif

#ifndef NS_SWIFT_SENDABLE
#define NS_SWIFT_SENDABLE
#endif

#if defined(__OBJC__) && defined(WEBKIT_IOS6_OBJC_EXTRAS)
#import <AVFoundation/AVAudioSession.h>
#import <AVFoundation/AVFoundation.h>
#endif


#ifndef __counted_by
#define __counted_by(N)
#endif
#ifndef __sized_by
#define __sized_by(N)
#endif
#ifndef __ended_by
#define __ended_by(E)
#endif
#ifndef __terminated_by
#define __terminated_by(T)
#endif
#ifndef __null_terminated
#define __null_terminated
#endif
#ifndef __unsafe_indexable
#define __unsafe_indexable
#endif
#ifndef __bidi_indexable
#define __bidi_indexable
#endif
#ifndef __single
#define __single
#endif


#ifndef kAudioChannelLayoutTag_Ogg_3_0
#define kAudioChannelLayoutTag_Ogg_3_0 kAudioChannelLayoutTag_AC3_3_0
#endif
#ifndef kAudioChannelLayoutTag_Ogg_4_0
#define kAudioChannelLayoutTag_Ogg_4_0 kAudioChannelLayoutTag_WAVE_4_0_B
#endif
#ifndef kAudioChannelLayoutTag_Ogg_5_0
#define kAudioChannelLayoutTag_Ogg_5_0 ((212U << 16) | 5)
#endif
#ifndef kAudioChannelLayoutTag_Ogg_5_1
#define kAudioChannelLayoutTag_Ogg_5_1 ((213U << 16) | 6)
#endif
#ifndef kAudioChannelLayoutTag_Ogg_6_1
#define kAudioChannelLayoutTag_Ogg_6_1 ((214U << 16) | 7)
#endif
#ifndef kAudioChannelLayoutTag_Ogg_7_1
#define kAudioChannelLayoutTag_Ogg_7_1 ((215U << 16) | 8)
#endif

#ifndef kCTFontVariationAxesAttribute
#define kCTFontVariationAxesAttribute kCTFontVariationAttribute
#endif

#ifndef kCVPixelFormatType_30RGB_r210
#define kCVPixelFormatType_30RGB_r210 'r210'
#endif
#ifndef kCVPixelFormatType_4444AYpCbCrFloat
#define kCVPixelFormatType_4444AYpCbCrFloat 'r4fl'
#endif

#ifndef kCVPixelFormatType_30RGBLE_8A_BiPlanar
#define kCVPixelFormatType_30RGBLE_8A_BiPlanar 'b3a8'
#endif
#ifndef kCVPixelFormatType_30RGB_r210
#define kCVPixelFormatType_30RGB_r210 'r210'
#endif
#ifndef kCVPixelFormatType_4444AYpCbCrFloat
#define kCVPixelFormatType_4444AYpCbCrFloat 'r4fl'
#endif
#ifndef kCVPixelFormatType_96VersatileBayerPacked12
#define kCVPixelFormatType_96VersatileBayerPacked12 'btp2'
#endif
#ifndef kCVPixelFormatType_Lossless_30RGBLEPackedWideGamut
#define kCVPixelFormatType_Lossless_30RGBLEPackedWideGamut '&w3r'
#endif
#ifndef kCVPixelFormatType_Lossless_30RGBLE_8A_BiPlanar
#define kCVPixelFormatType_Lossless_30RGBLE_8A_BiPlanar '&b38'
#endif
#ifndef kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarFullRange
#define kCVPixelFormatType_Lossless_420YpCbCr10PackedBiPlanarFullRange '&xf0'
#endif
#ifndef kCVPixelFormatType_Lossless_64RGBAHalf
#define kCVPixelFormatType_Lossless_64RGBAHalf '&RhA'
#endif

#ifndef kCGColorSpaceExtendedDisplayP3
#define kCGColorSpaceExtendedDisplayP3 kCGColorSpaceExtendedLinearSRGB
#endif
#ifndef kCGColorSpaceExtendedITUR_2020
#define kCGColorSpaceExtendedITUR_2020 kCGColorSpaceExtendedLinearSRGB
#endif
#ifndef kCGColorSpaceLinearDisplayP3
#define kCGColorSpaceLinearDisplayP3 kCGColorSpaceLinearSRGB
#endif

#include <Security/SecTrust.h>
#ifdef __cplusplus
extern "C"
#endif
CFArrayRef SecTrustCopyCertificateChain(SecTrustRef trust);

#if defined(__OBJC__)
#include <os/object.h>
#ifndef NW_OBJECT_DECL_SUBCLASS
#if OS_OBJECT_USE_OBJC
#define NW_OBJECT_DECL_SUBCLASS(type, base) OS_OBJECT_DECL_SUBCLASS(type, base)
#else
#define NW_OBJECT_DECL_SUBCLASS(type, base) \
    struct type;                            \
    typedef struct type *type##_t
#endif
#endif

#import <Foundation/NSError.h>
@interface NSError (WebKitIOS6UnderlyingErrors)
@property (readonly) NSArray<NSError *> *underlyingErrors;
@end
#endif

#if defined(__OBJC__)
#import <UIKit/UIScreen.h>
@interface UIScreen (WebKitIOS6EDR)
@property (readonly) CGFloat currentEDRHeadroom;
@property (readonly) CGFloat potentialEDRHeadroom;
@end
#endif
