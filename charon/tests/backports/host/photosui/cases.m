#import <PhotosUI/PhotosUI.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void answer(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
    fflush(stdout);
}

static void ask(NSString *name, void (^block)(void))
{
    fflush(stdout);
    fflush(stderr);
    int channel[2];
    if (pipe(channel) != 0) {
        answer(name, @"no pipe");
        return;
    }
    pid_t child = fork();
    if (child == 0) {
        close(channel[0]);
        dup2(channel[1], STDOUT_FILENO);
        close(channel[1]);
        @try {
            block();
        } @catch (NSException *exception) {
            answer(name, [@"raised " stringByAppendingString:exception.name]);
            fflush(stdout);
            _exit(0);
        }
        fflush(stdout);
        _exit(0);
    }
    close(channel[1]);
    char seen[4096];
    size_t used = 0;
    ssize_t got;
    while (used + 1 < sizeof seen && (got = read(channel[0], seen + used, sizeof seen - 1 - used)) > 0)
        used += (size_t)got;
    seen[used] = 0;
    close(channel[0]);
    int status = 0;
    waitpid(child, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        answer(name, @"aborted");
        return;
    }
    if (used == 0) {
        answer(name, @"no answer");
        return;
    }
    fputs(seen, stdout);
    fflush(stdout);
}

static void ask_filter(NSString *label, id (^block)(void))
{
    NSString *name = [@"filter." stringByAppendingString:label];
    ask(name, ^{
        id value = nil;
        @try {
            value = block();
        } @catch (NSException *exception) {
            answer(name, [@"raised " stringByAppendingString:exception.name]);
            return;
        }
        answer(name, value ? NSStringFromClass([value class]) : @"(nil)");
    });
}

static NSString *number(long value)
{
    return [NSString stringWithFormat:@"%ld", value];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        ask_filter(@"images", ^id { return PHPickerFilter.imagesFilter; });
        ask_filter(@"videos", ^id { return PHPickerFilter.videosFilter; });
        ask_filter(@"livePhotos", ^id { return PHPickerFilter.livePhotosFilter; });
        ask_filter(@"panoramas", ^id { return PHPickerFilter.panoramasFilter; });
        ask_filter(@"screenshots", ^id { return PHPickerFilter.screenshotsFilter; });
        ask_filter(@"screenRecordings", ^id { return PHPickerFilter.screenRecordingsFilter; });
        ask_filter(@"slomoVideos", ^id { return PHPickerFilter.slomoVideosFilter; });
        ask_filter(@"timelapseVideos", ^id { return PHPickerFilter.timelapseVideosFilter; });
        ask_filter(@"depthEffectPhotos", ^id { return PHPickerFilter.depthEffectPhotosFilter; });
        ask_filter(@"bursts", ^id { return PHPickerFilter.burstsFilter; });
        ask_filter(@"cinematicVideos", ^id { return PHPickerFilter.cinematicVideosFilter; });

        ask(@"all.ofBoth", ^{
            PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter]];
            answer(@"all.ofBoth", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"all.ofEmpty", ^{
            PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:@[]];
            answer(@"all.ofEmpty", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"all.ofNil", ^{
            PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:nil];
            answer(@"all.ofNil", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"all.ofImagesTwice", ^{
            PHPickerFilter *filter = [PHPickerFilter allFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.imagesFilter]];
            answer(@"all.ofImagesTwice", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"not.ofImages", ^{
            PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:PHPickerFilter.imagesFilter];
            answer(@"not.ofImages", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"not.ofVideos", ^{
            PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:PHPickerFilter.videosFilter];
            answer(@"not.ofVideos", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"not.ofBoth", ^{
            PHPickerFilter *both = [PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter]];
            PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:both];
            answer(@"not.ofBoth", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });
        ask(@"not.ofNil", ^{
            PHPickerFilter *filter = [PHPickerFilter notFilterOfSubfilter:nil];
            answer(@"not.ofNil", filter ? NSStringFromClass([filter class]) : @"(nil)");
        });

        for (NSInteger style = PHAssetPlaybackStyleUnsupported; style <= PHAssetPlaybackStyleVideoLooping; style++) {
            NSString *name = [NSString stringWithFormat:@"playbackStyle.%ld", (long)style];
            ask(name, ^{
                PHPickerFilter *filter = [PHPickerFilter playbackStyleFilter:(PHAssetPlaybackStyle)style];
                answer(name, filter ? NSStringFromClass([filter class]) : @"(nil)");
            });
        }

        ask(@"config", ^{
            PHPickerConfiguration *fresh = [[PHPickerConfiguration alloc] init];
            PHPickerConfiguration *freshCopy = [fresh copy];
            answer(@"config.selection.default", number(fresh.selection));
            answer(@"config.selectionLimit.default", number(fresh.selectionLimit));
            answer(@"config.preselected.default.count", number((long)fresh.preselectedAssetIdentifiers.count));
            answer(@"config.preselected.default.nonnull", fresh.preselectedAssetIdentifiers ? @"yes" : @"no");
            answer(@"config.copy.ofFresh.selection", number(freshCopy.selection));
            answer(@"config.copy.ofFresh.preselected.count", number((long)freshCopy.preselectedAssetIdentifiers.count));

            PHPickerConfiguration *set = [[PHPickerConfiguration alloc] init];
            set.selection = PHPickerConfigurationSelectionOrdered;
            set.preselectedAssetIdentifiers = @[@"one", @"two"];
            set.selectionLimit = 3;
            set.filter = PHPickerFilter.imagesFilter;
            PHPickerConfiguration *copy = [set copy];
            answer(@"config.copy.distinct", copy != set ? @"yes" : @"no");
            answer(@"config.copy.selection", number(copy.selection));
            answer(@"config.copy.preselected.count", number((long)copy.preselectedAssetIdentifiers.count));
            answer(@"config.copy.preselected.first", copy.preselectedAssetIdentifiers.firstObject ?: @"(nil)");
            answer(@"config.copy.selectionLimit", number(copy.selectionLimit));
            answer(@"config.copy.filter.nonnull", copy.filter ? @"yes" : @"no");
        });

        ask(@"picker.selection.methods", ^{
            PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:[[PHPickerConfiguration alloc] init]];
            [picker deselectAssetsWithIdentifiers:@[@"nonesuch"]];
            [picker moveAssetWithIdentifier:@"nonesuch" afterAssetWithIdentifier:nil];
            answer(@"picker.selection.methods", @"no raise");
        });
    }
    return 0;
}
