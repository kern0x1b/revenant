#import <Foundation/Foundation.h>

static void revenant_put_u16(NSMutableData *data, uint16_t value)
{
    uint8_t bytes[2] = {value & 0xff, (value >> 8) & 0xff};
    [data appendBytes:bytes length:2];
}

static void revenant_put_u32(NSMutableData *data, uint32_t value)
{
    uint8_t bytes[4] = {value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff};
    [data appendBytes:bytes length:4];
}

static NSURL *revenant_write_wave(NSString *name, NSTimeInterval seconds)
{
    const uint32_t rate = 8000, samples = (uint32_t)(seconds * rate);
    const uint32_t dataLength = samples * 2;
    NSMutableData *wave = [NSMutableData data];
    [wave appendBytes:"RIFF" length:4];
    revenant_put_u32(wave, 36 + dataLength);
    [wave appendBytes:"WAVEfmt " length:8];
    revenant_put_u32(wave, 16);
    revenant_put_u16(wave, 1);
    revenant_put_u16(wave, 1);
    revenant_put_u32(wave, rate);
    revenant_put_u32(wave, rate * 2);
    revenant_put_u16(wave, 2);
    revenant_put_u16(wave, 16);
    [wave appendBytes:"data" length:4];
    revenant_put_u32(wave, dataLength);
    [wave increaseLengthBy:dataLength];
    NSURL *url = [NSURL fileURLWithPath:name];
    [wave writeToURL:url atomically:NO];
    return url;
}
