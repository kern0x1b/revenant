#import <Foundation/Foundation.h>

@interface CharonHostNSProgress : NSObject
+ (instancetype)progressWithTotalUnitCount:(int64_t)unitCount;
+ (CharonHostNSProgress *)currentProgress;
- (instancetype)initWithParent:(CharonHostNSProgress *)parent userInfo:(NSDictionary *)userInfo;
- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount;
- (void)resignCurrent;
@property int64_t totalUnitCount;
@property int64_t completedUnitCount;
@property (readonly) double fractionCompleted;
@property (readonly, getter=isIndeterminate) BOOL indeterminate;
@property (getter=isCancellable) BOOL cancellable;
@property (getter=isPausable) BOOL pausable;
@property (readonly, getter=isCancelled) BOOL cancelled;
@property (readonly, getter=isPaused) BOOL paused;
@property (nullable, copy) void (^cancellationHandler)(void);
@property (nullable, copy) void (^pausingHandler)(void);
@property (nullable, copy) void (^resumingHandler)(void);
@property (nullable, copy) NSString *kind;
@property (readonly, copy) NSDictionary *userInfo;
- (void)setUserInfoObject:(id)object forKey:(NSString *)key;
- (void)cancel;
- (void)pause;
- (void)resume;
@end

static int failures;
static int checks;

static void expect(BOOL ok, NSString *what, NSString *detail)
{
    checks++;
    if (ok)
        return;
    failures++;
    printf("FAIL %s: %s\n", what.UTF8String, detail.UTF8String);
}

static void sameDouble(double ours, double theirs, NSString *what)
{
    expect(ours == theirs || (isnan(ours) && isnan(theirs)), what, [NSString stringWithFormat:@"ours %g, host %g", ours, theirs]);
}

static void sameInt(int64_t ours, int64_t theirs, NSString *what)
{
    expect(ours == theirs, what, [NSString stringWithFormat:@"ours %lld, host %lld", (long long)ours, (long long)theirs]);
}

static void sameBool(BOOL ours, BOOL theirs, NSString *what)
{
    expect(ours == theirs, what, [NSString stringWithFormat:@"ours %d, host %d", ours, theirs]);
}

static void sameObject(id ours, id theirs, NSString *what)
{
    expect(ours == theirs || [ours isEqual:theirs], what, [NSString stringWithFormat:@"ours %@, host %@", ours, theirs]);
}

static void tolerated(NSString *reason, NSString *what, id ours, id theirs)
{
    printf("tolerated %s: %s\n    ours %s\n    host %s\n", reason.UTF8String, what.UTF8String, [ours description].UTF8String, [theirs description].UTF8String);
}

int main(void)
{
    @autoreleasepool {
        Class ours = [CharonHostNSProgress class];
        Class theirs = [NSProgress class];
        expect(ours != theirs, @"the classes are two", @"one class");

        for (int i = 0; i <= 4; i++) {
            CharonHostNSProgress *o = [CharonHostNSProgress progressWithTotalUnitCount:4];
            NSProgress *t = [NSProgress progressWithTotalUnitCount:4];
            o.completedUnitCount = i;
            t.completedUnitCount = i;
            NSString *what = [NSString stringWithFormat:@"leaf %d/4", i];
            sameInt(o.completedUnitCount, t.completedUnitCount, [what stringByAppendingString:@" completedUnitCount"]);
            sameDouble(o.fractionCompleted, t.fractionCompleted, [what stringByAppendingString:@" fractionCompleted"]);
        }

        CharonHostNSProgress *zeroOurs = [CharonHostNSProgress progressWithTotalUnitCount:0];
        NSProgress *zeroTheirs = [NSProgress progressWithTotalUnitCount:0];
        expect(isnan(zeroOurs.fractionCompleted), @"zero total fractionCompleted is NaN (ours, iOS 6)", [NSString stringWithFormat:@"%g", zeroOurs.fractionCompleted]);
        if (isnan(zeroTheirs.fractionCompleted))
            sameDouble(zeroOurs.fractionCompleted, zeroTheirs.fractionCompleted, @"zero total fractionCompleted (host too)");
        else
            tolerated(@"iOS 6 answers NaN for a zero total; the newest release does not", @"zero total fractionCompleted", @(zeroOurs.fractionCompleted), @(zeroTheirs.fractionCompleted));

        CharonHostNSProgress *negOurs = [CharonHostNSProgress progressWithTotalUnitCount:-1];
        NSProgress *negTheirs = [NSProgress progressWithTotalUnitCount:-1];
        sameBool(negOurs.isIndeterminate, negTheirs.isIndeterminate, @"negative total is indeterminate");
        expect(negOurs.isIndeterminate, @"negative total is indeterminate (ours)", @"NO");

        CharonHostNSProgress *freshOurs = [CharonHostNSProgress progressWithTotalUnitCount:0];
        NSProgress *freshTheirs = [NSProgress progressWithTotalUnitCount:0];
        expect(freshOurs.isIndeterminate == NO, @"a fresh progress's isIndeterminate is NO (ours, iOS 6)", [NSString stringWithFormat:@"%d", freshOurs.isIndeterminate]);
        if (freshTheirs.isIndeterminate == NO)
            sameBool(freshOurs.isIndeterminate, freshTheirs.isIndeterminate, @"a fresh progress's isIndeterminate (host too)");
        else
            tolerated(@"iOS 6 answers NO for a fresh progress; the newest release may answer YES", @"a fresh progress's isIndeterminate", @(freshOurs.isIndeterminate), @(freshTheirs.isIndeterminate));

        sameBool([CharonHostNSProgress new].isCancellable, [NSProgress new].isCancellable, @"isCancellable default");
        sameBool([CharonHostNSProgress new].isPausable, [NSProgress new].isPausable, @"isPausable default");

        __block int oursHandlerCalls = 0, theirsHandlerCalls = 0;
        CharonHostNSProgress *cancelOurs = [CharonHostNSProgress progressWithTotalUnitCount:1];
        NSProgress *cancelTheirs = [NSProgress progressWithTotalUnitCount:1];
        cancelOurs.cancellationHandler = ^{ oursHandlerCalls++; };
        cancelTheirs.cancellationHandler = ^{ theirsHandlerCalls++; };
        [cancelOurs cancel];
        [cancelTheirs cancel];
        sameBool(cancelOurs.isCancelled, cancelTheirs.isCancelled, @"isCancelled after cancel");
        sameInt(oursHandlerCalls, 1, @"the cancellation handler fired once (ours, synchronously)");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        sameInt(theirsHandlerCalls, 1, @"the cancellation handler fired once (host, after the wait)");
        oursHandlerCalls = theirsHandlerCalls = 0;
        CharonHostNSProgress *lateOurs = [CharonHostNSProgress progressWithTotalUnitCount:1];
        NSProgress *lateTheirs = [NSProgress progressWithTotalUnitCount:1];
        [lateOurs cancel];
        [lateTheirs cancel];
        lateOurs.cancellationHandler = ^{ oursHandlerCalls++; };
        lateTheirs.cancellationHandler = ^{ theirsHandlerCalls++; };
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        expect(oursHandlerCalls == 0, @"a handler set after cancel is not called (ours, iOS 6)", [NSString stringWithFormat:@"%d", oursHandlerCalls]);
        if (theirsHandlerCalls == 0)
            sameInt(theirsHandlerCalls, 0, @"a handler set after cancel is not called (host too)");
        else
            tolerated(@"the newest release calls a cancellation handler set after cancel; iOS 6 does not", @"a handler set after cancel", @(oursHandlerCalls), @(theirsHandlerCalls));

        __block int oursPauseCalls = 0, theirsPauseCalls = 0;
        CharonHostNSProgress *pauseOurs = [CharonHostNSProgress progressWithTotalUnitCount:1];
        NSProgress *pauseTheirs = [NSProgress progressWithTotalUnitCount:1];
        pauseOurs.pausable = YES;
        pauseTheirs.pausable = YES;
        pauseOurs.pausingHandler = ^{ oursPauseCalls++; };
        pauseTheirs.pausingHandler = ^{ theirsPauseCalls++; };
        [pauseOurs pause];
        [pauseTheirs pause];
        sameBool(pauseOurs.isPaused, pauseTheirs.isPaused, @"isPaused after pause");
        sameInt(oursPauseCalls, 1, @"the pausing handler fired once (ours, synchronously)");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        sameInt(theirsPauseCalls, 1, @"the pausing handler fired once (host, after the wait)");

        [pauseOurs resume];
        [pauseTheirs resume];
        expect(pauseOurs.isPaused == YES, @"a progress is still paused after resume (ours, iOS 6 has no way back)", [NSString stringWithFormat:@"%d", pauseOurs.isPaused]);
        if (pauseTheirs.isPaused == YES)
            sameBool(pauseOurs.isPaused, pauseTheirs.isPaused, @"isPaused after resume (host too)");
        else
            tolerated(@"iOS 6 cannot resume a paused progress; the host, since 10.11, can", @"isPaused after resume", @(pauseOurs.isPaused), @(pauseTheirs.isPaused));

        CharonHostNSProgress *infoOurs = [CharonHostNSProgress progressWithTotalUnitCount:1];
        NSProgress *infoTheirs = [NSProgress progressWithTotalUnitCount:1];
        [infoOurs setUserInfoObject:@"x" forKey:@"k"];
        [infoTheirs setUserInfoObject:@"x" forKey:@"k"];
        sameObject(infoOurs.userInfo[@"k"], infoTheirs.userInfo[@"k"], @"userInfo roundtrip");
        [infoOurs setUserInfoObject:nil forKey:@"k"];
        [infoTheirs setUserInfoObject:nil forKey:@"k"];
        sameObject(infoOurs.userInfo[@"k"] ?: @"nil", infoTheirs.userInfo[@"k"] ?: @"nil", @"userInfo removed");
        infoOurs.kind = @"custom";
        infoTheirs.kind = @"custom";
        sameObject(infoOurs.kind, infoTheirs.kind, @"kind roundtrip");

        CharonHostNSProgress *rootOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
        NSProgress *rootTheirs = [NSProgress progressWithTotalUnitCount:10];
        [rootOurs becomeCurrentWithPendingUnitCount:6];
        [rootTheirs becomeCurrentWithPendingUnitCount:6];
        CharonHostNSProgress *childOurs = [CharonHostNSProgress progressWithTotalUnitCount:4];
        NSProgress *childTheirs = [NSProgress progressWithTotalUnitCount:4];
        [rootOurs resignCurrent];
        [rootTheirs resignCurrent];
        sameDouble(rootOurs.fractionCompleted, rootTheirs.fractionCompleted, @"implicit child, none done yet");
        childOurs.completedUnitCount = 2;
        childTheirs.completedUnitCount = 2;
        sameDouble(rootOurs.fractionCompleted, rootTheirs.fractionCompleted, @"implicit child, half done");
        childOurs.completedUnitCount = 4;
        childTheirs.completedUnitCount = 4;
        sameDouble(rootOurs.fractionCompleted, rootTheirs.fractionCompleted, @"implicit child, all done");

        CharonHostNSProgress *noChildOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
        NSProgress *noChildTheirs = [NSProgress progressWithTotalUnitCount:10];
        [noChildOurs becomeCurrentWithPendingUnitCount:3];
        [noChildTheirs becomeCurrentWithPendingUnitCount:3];
        [noChildOurs resignCurrent];
        [noChildTheirs resignCurrent];
        sameInt(noChildOurs.completedUnitCount, noChildTheirs.completedUnitCount, @"resignCurrent with no child, completedUnitCount");
        sameDouble(noChildOurs.fractionCompleted, noChildTheirs.fractionCompleted, @"resignCurrent with no child, fractionCompleted");

        CharonHostNSProgress *twoOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
        NSProgress *twoTheirs = [NSProgress progressWithTotalUnitCount:10];
        [twoOurs becomeCurrentWithPendingUnitCount:10];
        [twoTheirs becomeCurrentWithPendingUnitCount:10];
        CharonHostNSProgress *firstOurs = [CharonHostNSProgress progressWithTotalUnitCount:2];
        NSProgress *firstTheirs = [NSProgress progressWithTotalUnitCount:2];
        CharonHostNSProgress *secondOurs = [CharonHostNSProgress progressWithTotalUnitCount:2];
        NSProgress *secondTheirs = [NSProgress progressWithTotalUnitCount:2];
        [twoOurs resignCurrent];
        [twoTheirs resignCurrent];
        firstOurs.completedUnitCount = 2;
        firstTheirs.completedUnitCount = 2;
        secondOurs.completedUnitCount = 2;
        secondTheirs.completedUnitCount = 2;
        sameDouble(twoOurs.fractionCompleted, twoTheirs.fractionCompleted, @"only the first of two attaches");

        CharonHostNSProgress *outerOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
        NSProgress *outerTheirs = [NSProgress progressWithTotalUnitCount:10];
        [outerOurs becomeCurrentWithPendingUnitCount:10];
        [outerTheirs becomeCurrentWithPendingUnitCount:10];
        CharonHostNSProgress *middleOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
        NSProgress *middleTheirs = [NSProgress progressWithTotalUnitCount:10];
        [middleOurs becomeCurrentWithPendingUnitCount:5];
        [middleTheirs becomeCurrentWithPendingUnitCount:5];
        CharonHostNSProgress *innerOurs = [CharonHostNSProgress progressWithTotalUnitCount:4];
        NSProgress *innerTheirs = [NSProgress progressWithTotalUnitCount:4];
        [middleOurs resignCurrent];
        [middleTheirs resignCurrent];
        [outerOurs resignCurrent];
        [outerTheirs resignCurrent];
        innerOurs.completedUnitCount = 2;
        innerTheirs.completedUnitCount = 2;
        sameDouble(outerOurs.fractionCompleted, outerTheirs.fractionCompleted, @"a nested becomeCurrent scope, outer fraction");
        sameDouble(middleOurs.fractionCompleted, middleTheirs.fractionCompleted, @"a nested becomeCurrent scope, middle fraction");

        __weak CharonHostNSProgress *weakOurs;
        __weak NSProgress *weakTheirs;
        @autoreleasepool {
            CharonHostNSProgress *earlyOurs = [CharonHostNSProgress progressWithTotalUnitCount:10];
            NSProgress *earlyTheirs = [NSProgress progressWithTotalUnitCount:10];
            [earlyOurs cancel];
            [earlyTheirs cancel];
            [earlyOurs becomeCurrentWithPendingUnitCount:10];
            [earlyTheirs becomeCurrentWithPendingUnitCount:10];
            CharonHostNSProgress *afterOurs = [CharonHostNSProgress progressWithTotalUnitCount:4];
            NSProgress *afterTheirs = [NSProgress progressWithTotalUnitCount:4];
            [earlyOurs resignCurrent];
            [earlyTheirs resignCurrent];
            weakOurs = afterOurs;
            weakTheirs = afterTheirs;
            sameBool(afterOurs.isCancelled, afterTheirs.isCancelled, @"a child attached to an already-cancelled parent is cancelled too");
            earlyOurs = nil;
            earlyTheirs = nil;
        }
        expect(weakOurs == nil, @"a child dropped after its parent is not kept alive by anything of this class's own", @"still alive");
        expect(weakTheirs == nil, @"the host's own child is not kept alive either, for the same comparison", @"still alive");
    }
    printf("%d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
