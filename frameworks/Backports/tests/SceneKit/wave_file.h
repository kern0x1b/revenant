#import <Foundation/Foundation.h>
#include <math.h>

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

static NSURL *revenant_write_wave_samples(NSString *name, uint32_t rate, uint32_t samples, double frequency)
{
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
    for (uint32_t index = 0; index < samples; index++) {
        double value = frequency > 0 ? 0.5 * sin(2 * M_PI * frequency * index / rate) : 0;
        revenant_put_u16(wave, (uint16_t)(int16_t)lrint(value * 32767));
    }
    NSURL *url = [NSURL fileURLWithPath:name];
    [wave writeToURL:url atomically:NO];
    return url;
}

static NSURL *revenant_write_wave(NSString *name, NSTimeInterval seconds)
{
    return revenant_write_wave_samples(name, 8000, (uint32_t)(seconds * 8000), 0);
}

static NSURL *revenant_write_tone(NSString *name, NSTimeInterval seconds, double frequency)
{
    return revenant_write_wave_samples(name, 8000, (uint32_t)(seconds * 8000), frequency);
}

static NSString *revenant_fixture_directory(void)
{
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return directory;
}
