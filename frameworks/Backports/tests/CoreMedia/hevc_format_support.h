#ifndef REVENANT_HEVC_FORMAT_SUPPORT_H
#define REVENANT_HEVC_FORMAT_SUPPORT_H

#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const uint8_t *bytes;
    size_t size;
} RevenantHEVCSet;

typedef struct {
    const char *name;
    const RevenantHEVCSet *sets;
    size_t count;
    int nalLength;
    int extensions;
    int nullOut;
    int32_t status;
    const char *dump;
} RevenantHEVCCase;

typedef struct {
    char *data;
    size_t capacity;
    size_t length;
    int overflow;
} RevenantHEVCText;

static void revenant_hevc_text_init(RevenantHEVCText *text, char *data, size_t capacity)
{
    text->data = data;
    text->capacity = capacity;
    text->length = 0;
    text->overflow = 0;
    if (capacity)
        data[0] = 0;
}

static void revenant_hevc_text_put(RevenantHEVCText *text, const char *value, size_t length)
{
    if (text->overflow)
        return;
    if (text->length + length + 1 > text->capacity) {
        text->overflow = 1;
        return;
    }
    memcpy(text->data + text->length, value, length);
    text->length += length;
    text->data[text->length] = 0;
}

static void revenant_hevc_text_add(RevenantHEVCText *text, const char *value)
{
    revenant_hevc_text_put(text, value, strlen(value));
}

static void revenant_hevc_text_value(RevenantHEVCText *text, CFTypeRef value);

static void revenant_hevc_text_string(RevenantHEVCText *text, CFStringRef value)
{
    char buffer[512];
    if (!CFStringGetCString(value, buffer, sizeof buffer, kCFStringEncodingUTF8)) {
        revenant_hevc_text_add(text, "?");
        return;
    }
    revenant_hevc_text_add(text, "'");
    revenant_hevc_text_add(text, buffer);
    revenant_hevc_text_add(text, "'");
}

static void revenant_hevc_text_number(RevenantHEVCText *text, CFNumberRef value)
{
    long long number = 0;
    char buffer[32];
    CFNumberGetValue(value, kCFNumberLongLongType, &number);
    snprintf(buffer, sizeof buffer, "%lld", number);
    revenant_hevc_text_add(text, buffer);
}

static void revenant_hevc_text_data(RevenantHEVCText *text, CFDataRef value)
{
    const uint8_t *bytes = CFDataGetBytePtr(value);
    CFIndex length = CFDataGetLength(value);
    char hex[3];
    revenant_hevc_text_add(text, "<");
    for (CFIndex i = 0; i < length; i++) {
        snprintf(hex, sizeof hex, "%02x", bytes[i]);
        revenant_hevc_text_add(text, hex);
    }
    revenant_hevc_text_add(text, ">");
}

static void revenant_hevc_text_dictionary(RevenantHEVCText *text, CFDictionaryRef dictionary)
{
    CFIndex count = CFDictionaryGetCount(dictionary);
    const void **keys = malloc(sizeof(void *) * (count ? count : 1));
    const void **values = malloc(sizeof(void *) * (count ? count : 1));
    CFDictionaryGetKeysAndValues(dictionary, keys, values);
    char **names = malloc(sizeof(char *) * (count ? count : 1));
    CFIndex *order = malloc(sizeof(CFIndex) * (count ? count : 1));
    for (CFIndex i = 0; i < count; i++) {
        names[i] = malloc(512);
        if (!CFStringGetCString(keys[i], names[i], 512, kCFStringEncodingUTF8))
            names[i][0] = 0;
        order[i] = i;
    }
    for (CFIndex i = 0; i < count; i++) {
        for (CFIndex j = i + 1; j < count; j++) {
            if (strcmp(names[order[j]], names[order[i]]) < 0) {
                CFIndex swap = order[i];
                order[i] = order[j];
                order[j] = swap;
            }
        }
    }
    revenant_hevc_text_add(text, "{");
    for (CFIndex i = 0; i < count; i++) {
        CFIndex index = order[i];
        revenant_hevc_text_add(text, names[index]);
        revenant_hevc_text_add(text, "=");
        revenant_hevc_text_value(text, values[index]);
        revenant_hevc_text_add(text, ";");
    }
    revenant_hevc_text_add(text, "}");
    for (CFIndex i = 0; i < count; i++)
        free(names[i]);
    free(names);
    free(order);
    free(keys);
    free(values);
}

static void revenant_hevc_text_value(RevenantHEVCText *text, CFTypeRef value)
{
    if (!value) {
        revenant_hevc_text_add(text, "null");
        return;
    }
    CFTypeID type = CFGetTypeID(value);
    if (type == CFStringGetTypeID())
        revenant_hevc_text_string(text, (CFStringRef)value);
    else if (type == CFNumberGetTypeID())
        revenant_hevc_text_number(text, (CFNumberRef)value);
    else if (type == CFBooleanGetTypeID())
        revenant_hevc_text_add(text, CFBooleanGetValue((CFBooleanRef)value) ? "true" : "false");
    else if (type == CFDataGetTypeID())
        revenant_hevc_text_data(text, (CFDataRef)value);
    else if (type == CFDictionaryGetTypeID())
        revenant_hevc_text_dictionary(text, (CFDictionaryRef)value);
    else
        revenant_hevc_text_add(text, "?");
}

static void revenant_hevc_describe(CMFormatDescriptionRef description, RevenantHEVCText *text)
{
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(description);
    FourCharCode codec = CMFormatDescriptionGetMediaSubType(description);
    char head[128];
    snprintf(head, sizeof head, "dims %dx%d codec %c%c%c%c ext ", dimensions.width, dimensions.height,
             (int)((codec >> 24) & 255), (int)((codec >> 16) & 255), (int)((codec >> 8) & 255), (int)(codec & 255));
    revenant_hevc_text_add(text, head);
    CFDictionaryRef extensions = CMFormatDescriptionGetExtensions(description);
    if (extensions)
        revenant_hevc_text_dictionary(text, extensions);
    else
        revenant_hevc_text_add(text, "null");
}

static CFDictionaryRef revenant_hevc_extensions(int mode)
{
    if (mode == 0)
        return NULL;
    CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (mode == 1)
        CFDictionarySetValue(extensions, CFSTR("FullRangeVideo"), kCFBooleanFalse);
    if (mode == 2 || mode == 5 || mode == 6) {
        CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        const uint8_t payload[3] = {'a', 'b', 'c'};
        CFDataRef data = CFDataCreate(kCFAllocatorDefault, payload, 3);
        CFDictionarySetValue(atoms, CFSTR("xyzz"), data);
        CFRelease(data);
        CFDictionarySetValue(extensions, CFSTR("SampleDescriptionExtensionAtoms"), atoms);
        CFRelease(atoms);
    }
    if (mode == 5)
        CFDictionarySetValue(extensions, CFSTR("FullRangeVideo"), kCFBooleanFalse);
    if (mode == 6)
        CFDictionarySetValue(extensions, CFSTR("CustomKey"), CFSTR("custom"));
    if (mode == 3)
        CFDictionarySetValue(extensions, CFSTR("CustomKey"), CFSTR("custom"));
    if (mode == 4)
        CFDictionarySetValue(extensions, CFSTR("CVImageBufferColorPrimaries"), CFSTR("CustomPrimaries"));
    if (mode == 7)
        CFDictionarySetValue(extensions, CFSTR("CVImageBufferTransferFunction"), CFSTR("CustomTransfer"));
    if (mode == 8)
        CFDictionarySetValue(extensions, CFSTR("CVImageBufferYCbCrMatrix"), CFSTR("CustomMatrix"));
    return extensions;
}

#endif
