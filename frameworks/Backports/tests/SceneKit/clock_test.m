#import "../Foundation/check.h"
#import "../../src/SceneKit/RevenantSCNClock.h"
#include <math.h>

static BOOL revenant_same(double value, double expected)
{
    return fabs(value - expected) < 1e-9;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);
        RevenantSCNClock *clock = [[RevenantSCNClock alloc] init];
        revenant_check(clock.isPlaying, "a new clock plays", @"a new clock is paused");
        revenant_check(revenant_same([clock sceneTimeAtWallTime:100], 100), "a new clock reads the wall time", @"a new clock does not read the wall time");
        revenant_check(revenant_same([clock sceneTimeAtWallTime:105], 105), "a playing clock follows the wall time", @"a playing clock does not follow the wall time");

        [clock setSceneTime:10 atWallTime:105];
        revenant_check(revenant_same([clock sceneTimeAtWallTime:105], 10), "setting the scene time sets it at once", @"the scene time is not set");
        revenant_check(revenant_same([clock sceneTimeAtWallTime:107], 12), "a playing clock advances from the time set", @"the time set does not advance");

        [clock setPlaying:NO atWallTime:107];
        revenant_check(!clock.isPlaying, "a paused clock is not playing", @"a paused clock still plays");
        revenant_check(revenant_same([clock sceneTimeAtWallTime:200], 12), "a paused clock holds its time", @"a paused clock moves");

        [clock setSceneTime:3 atWallTime:200];
        revenant_check(revenant_same([clock sceneTimeAtWallTime:300], 3), "a paused clock takes the time set", @"a paused clock ignores the time set");

        [clock setPlaying:YES atWallTime:300];
        revenant_check(revenant_same([clock sceneTimeAtWallTime:302], 5), "resuming continues from the held time", @"resuming does not continue from the held time");

        [clock setPlaying:YES atWallTime:310];
        revenant_check(revenant_same([clock sceneTimeAtWallTime:310], 13), "resuming a playing clock changes nothing", @"resuming a playing clock moves it");

        [clock setPlaying:NO atWallTime:310];
        [clock setPlaying:NO atWallTime:320];
        revenant_check(revenant_same([clock sceneTimeAtWallTime:320], 13), "pausing twice holds the first pause", @"the second pause moves the clock");

        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
