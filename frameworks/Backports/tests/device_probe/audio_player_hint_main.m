#import <AVFoundation/AVFoundation.h>
#import "check.h"

static NSString *const revenant_wave = @"com.microsoft.waveform-audio";
static NSString *const revenant_mp3 = @"public.mp3";

static NSData *revenant_tone(void)
{
    enum { rate = 8000, samples = 1600 };
    NSMutableData *wave = [NSMutableData data];
    uint32_t bytes = samples * 2;
    uint32_t chunk = 36 + bytes;
    uint32_t format = 16;
    uint16_t pcm = 1, channels = 1, align = 2, bits = 16;
    uint32_t sample_rate = rate, byte_rate = rate * 2;
    [wave appendBytes:"RIFF" length:4];
    [wave appendBytes:&chunk length:4];
    [wave appendBytes:"WAVEfmt " length:8];
    [wave appendBytes:&format length:4];
    [wave appendBytes:&pcm length:2];
    [wave appendBytes:&channels length:2];
    [wave appendBytes:&sample_rate length:4];
    [wave appendBytes:&byte_rate length:4];
    [wave appendBytes:&align length:2];
    [wave appendBytes:&bits length:2];
    [wave appendBytes:"data" length:4];
    [wave appendBytes:&bytes length:4];
    for (int index = 0; index < samples; index++) {
        int16_t sample = (int16_t)(8000.0 * sin(2.0 * M_PI * 440.0 * index / rate));
        [wave appendBytes:&sample length:2];
    }
    return wave;
}

static NSURL *revenant_file(NSString *folder, NSString *name, NSData *content)
{
    NSString *file = [folder stringByAppendingPathComponent:name];
    [content writeToFile:file atomically:NO];
    return [NSURL fileURLWithPath:file];
}

static BOOL revenant_plays(AVAudioPlayer *player)
{
    return player != nil && fabs(player.duration - 0.2) < 0.01 && player.numberOfChannels == 1;
}

static NSString *revenant_describe(AVAudioPlayer *player, NSError *error)
{
    return [NSString stringWithFormat:@"player %@ duration %.3f error %ld %@", player, player.duration, (long)error.code, error.domain];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-audio-hint"];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *tone = revenant_tone();
        NSURL *named_wav = revenant_file(folder, @"tone.wav", tone);
        NSURL *named_mp3 = revenant_file(folder, @"tone.mp3", tone);
        NSURL *unnamed = revenant_file(folder, @"tone", tone);
        NSURL *missing = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"missing.mp3"]];

        NSError *error = nil;
        AVAudioPlayer *stock = [[AVAudioPlayer alloc] initWithContentsOfURL:named_mp3 error:&error];
        revenant_check((stock == nil && error != nil) != revenant_negative, "the system cannot open a wave file whose name ends in .mp3", revenant_describe(stock, error));

        error = nil;
        AVAudioPlayer *hinted = [[AVAudioPlayer alloc] initWithContentsOfURL:named_mp3 fileTypeHint:revenant_wave error:&error];
        revenant_check(revenant_plays(hinted) != revenant_negative, "a hint that names the content's type overrides the extension", revenant_describe(hinted, error));

        error = nil;
        AVAudioPlayer *agreeing = [[AVAudioPlayer alloc] initWithContentsOfURL:named_wav fileTypeHint:revenant_wave error:&error];
        revenant_check((revenant_plays(agreeing) && [agreeing.url isEqual:named_wav]) != revenant_negative, "a hint that agrees with the extension keeps the url", revenant_describe(agreeing, error));

        error = nil;
        AVAudioPlayer *bare = [[AVAudioPlayer alloc] initWithContentsOfURL:unnamed fileTypeHint:revenant_mp3 error:&error];
        revenant_check((revenant_plays(bare) && [bare.url isEqual:unnamed]) != revenant_negative, "a file with no extension opens by its content and keeps the url", revenant_describe(bare, error));

        error = nil;
        AVAudioPlayer *unknown = [[AVAudioPlayer alloc] initWithContentsOfURL:named_mp3 fileTypeHint:@"mp3" error:&error];
        revenant_check((unknown == nil && error != nil) != revenant_negative, "a hint that is not a type identifier changes nothing", revenant_describe(unknown, error));

        error = nil;
        AVAudioPlayer *without = [[AVAudioPlayer alloc] initWithContentsOfURL:named_mp3 fileTypeHint:nil error:&error];
        revenant_check((without == nil && error != nil) != revenant_negative, "no hint changes nothing", revenant_describe(without, error));

        error = nil;
        AVAudioPlayer *absent = [[AVAudioPlayer alloc] initWithContentsOfURL:missing fileTypeHint:revenant_wave error:&error];
        revenant_check((absent == nil && error != nil) != revenant_negative, "a missing file reports its error", revenant_describe(absent, error));

        revenant_check(([[AVAudioPlayer alloc] initWithContentsOfURL:missing fileTypeHint:revenant_wave error:NULL] == nil) != revenant_negative, "the error is optional", @"a player for a missing file");

        error = nil;
        AVAudioPlayer *junk = [[AVAudioPlayer alloc] initWithContentsOfURL:revenant_file(folder, @"junk.mp3", [NSData dataWithBytes:"not audio" length:9]) fileTypeHint:revenant_wave error:&error];
        revenant_check((junk == nil && error != nil) != revenant_negative, "content that is not audio reports its error", revenant_describe(junk, error));

        error = nil;
        AVAudioPlayer *by_data = [[AVAudioPlayer alloc] initWithData:tone fileTypeHint:revenant_wave error:&error];
        revenant_check(revenant_plays(by_data) != revenant_negative, "data opens with a hint", revenant_describe(by_data, error));

        error = nil;
        AVAudioPlayer *data_without = [[AVAudioPlayer alloc] initWithData:tone fileTypeHint:nil error:&error];
        revenant_check(revenant_plays(data_without) != revenant_negative, "data opens without a hint", revenant_describe(data_without, error));

        [[NSFileManager defaultManager] removeItemAtPath:folder error:nil];
    }
    return revenant_finish();
}
