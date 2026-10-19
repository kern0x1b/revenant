#import "RevenantVideoToolbox.h"
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VTCompressionSession.h>
#include <VideoToolbox/VTErrors.h>



OSStatus VTCopySupportedPropertyDictionaryForEncoder(
    int32_t width, int32_t height, CMVideoCodecType codecType, CFDictionaryRef encoderSpecification,
    CFStringRef *encoderIDOut, CFDictionaryRef *supportedPropertiesOut)
{
    if (encoderIDOut)
        *encoderIDOut = NULL;
    if (supportedPropertiesOut)
        *supportedPropertiesOut = NULL;
    if (width <= 0 || height <= 0)
        return kVTParameterErr;

    static CFDictionaryRef empty = NULL;
    CFDictionaryRef specification = encoderSpecification;
    if (!specification) {
        if (!empty) {
            empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                       &kCFTypeDictionaryValueCallBacks);
        }
        specification = empty;
    }
    VTCompressionSessionRef session = NULL;
    OSStatus created = VTCompressionSessionCreate(kCFAllocatorDefault, width, height, codecType,
                                                  specification, NULL, NULL, NULL, NULL, &session);
    if (created != noErr || !session) {
        if (session)
            CFRelease(session);
        return created == noErr ? kVTCouldNotFindVideoEncoderErr : created;
    }

    OSStatus status = noErr;
    if (kVTCompressionPropertyKey_EncoderID) {
        CFTypeRef identifier = NULL;
        if (VTSessionCopyProperty(session, kVTCompressionPropertyKey_EncoderID, NULL, &identifier) == noErr &&
            identifier) {
            if (encoderIDOut)
                *encoderIDOut = (CFStringRef)identifier;
            else
                CFRelease(identifier);
        }
    }
    CFDictionaryRef supported = NULL;
    if (VTSessionCopySupportedPropertyDictionary(session, &supported) == noErr && supported) {
        if (supportedPropertiesOut)
            *supportedPropertiesOut = supported;
        else
            CFRelease(supported);
    }
    VTCompressionSessionInvalidate(session);
    CFRelease(session);
    return status;
}
