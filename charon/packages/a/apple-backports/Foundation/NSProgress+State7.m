#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The state of a progress: whether it is paused, what it says beyond its description, and the block
   to run when it resumes. Three of the five members are in NSProgress+Additions.m; they are here
   because they are one subject, the progress's own state.

   -isIndeterminate: the header says YES when the total or the completed count is less than zero, and
   NO when both are zero; the host answers YES for both zero (measured: a fresh NSProgress with no
   units, and one with 10 of 10 units answers NO), so the rule the port follows is the measured one:
   a total of zero or less, or a negative completed count. -[NSProgress pause] and -[NSProgress resume]
   are in the same file as the handlers they call, and they set and clear the flag. The resuming
   handler runs only when the progress was paused: the host does not call it when -resume is invoked
   on a progress that was never paused (measured). */

static char CharonProgressPausedKey;
static char CharonProgressAdditionalKey;
static char CharonProgressResumingKey;

@implementation NSProgress (CharonState)

- (BOOL)isIndeterminate
{
    /* Measured over the seven pairs the differential holds: a negative total, a negative completed
       count, or both counts zero. A total of zero with work already done is not indeterminate, which
       a total of zero on its own would wrongly say. */
    return self.totalUnitCount < 0 || self.completedUnitCount < 0 ||
           (self.totalUnitCount == 0 && self.completedUnitCount == 0);
}

- (BOOL)isPaused
{
    return [objc_getAssociatedObject(self, &CharonProgressPausedKey) boolValue];
}

- (NSString *)localizedAdditionalDescription
{
    return objc_getAssociatedObject(self, &CharonProgressAdditionalKey);
}

- (void)setLocalizedAdditionalDescription:(NSString *)description
{
    /* A null_resettable property: nil puts the default back, and the default is what the file counts
       in the user info make of themselves. */
    if (!description) {
        NSNumber *total = [self.userInfo objectForKey:NSProgressFileTotalCountKey];
        NSNumber *done = [self.userInfo objectForKey:NSProgressFileCompletedCountKey];
        if (total && done)
            description = [NSString stringWithFormat:@"%@ of %@", done, total];
    }
    objc_setAssociatedObject(self, &CharonProgressAdditionalKey, [description copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(void))resumingHandler
{
    return objc_getAssociatedObject(self, &CharonProgressResumingKey);
}

- (void)setResumingHandler:(void (^)(void))handler
{
    objc_setAssociatedObject(self, &CharonProgressResumingKey, [handler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* The handler, reached by its own name: a category cannot use dot syntax for a method the selector
   rewriter renames, and this file's own reader wants the renamed one. */
- (void (^)(void))charon_progressResumingHandler
{
    return objc_getAssociatedObject(self, &CharonProgressResumingKey);
}

- (void)resume
{
    BOOL wasPaused = self.isPaused;
    if (wasPaused)
        objc_setAssociatedObject(self, &CharonProgressPausedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    void (^handler)(void) = [self charon_progressResumingHandler];
    if (handler && wasPaused)
        handler();
}

@end
