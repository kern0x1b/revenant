#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <objc/message.h>

#pragma once

#define REVENANT_GCGAMEPAD_SNAPSHOT_VERSION_V100 0x0100

static inline NSData *revenant_gc_snapshot_data(const void *bytes, size_t length, uint16_t version)
{
    if (bytes == NULL)
        return nil;
    void *copy = malloc(length);
    if (copy == NULL)
        return nil;
    memcpy(copy, bytes, length);
    if (length >= 4) {
        uint16_t *header = (uint16_t *)copy;
        if (header[0] == 0)
            header[0] = version;
        if (header[1] == 0)
            header[1] = (uint16_t)length;
    }
    return [NSData dataWithBytesNoCopy:copy length:length freeWhenDone:YES];
}

static inline BOOL revenant_gc_accept_whole_structure(NSData *data, size_t length)
{
    if (data.length < 4)
        return NO;
    uint16_t header[2] = {0, 0};
    [data getBytes:header length:4];
    return data.length >= length && header[0] != 0;
}

static inline BOOL revenant_gc_accept_declared_size(NSData *data, size_t length)
{
    if (data.length < 4)
        return YES;
    uint16_t header[2] = {0, 0};
    [data getBytes:header length:4];
    return header[1] <= length;
}

static inline BOOL revenant_gc_snapshot_read(void *out, NSData *data, size_t length, BOOL (*accepts)(NSData *, size_t))
{
    if (out == NULL || data == nil)
        return NO;
    if (!accepts(data, length))
        return NO;
    memset(out, 0, length);
    NSUInteger take = MIN((NSUInteger)length, data.length);
    if (take > 0)
        [data getBytes:out length:take];
    return YES;
}

static inline float revenant_gc_read_float(id element, SEL which)
{
    if (element == nil || ![element respondsToSelector:which])
        return 0.0f;
    float (*read)(id, SEL) = (float (*)(id, SEL))objc_msgSend;
    return read(element, which);
}

static inline float revenant_gc_button_value(id element)
{
    return revenant_gc_read_float(element, @selector(value));
}

static inline float revenant_gc_pad_axis(id pad, SEL axis)
{
    if (pad == nil || ![pad respondsToSelector:axis])
        return 0.0f;
    id element = ((id (*)(id, SEL))objc_msgSend)(pad, axis);
    return revenant_gc_read_float(element, @selector(value));
}
