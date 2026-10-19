#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char CharonProgressPausedKey;
static char CharonProgressAdditionalKey;
static char CharonProgressResumingKey;

@implementation NSProgress (CharonState)

- (BOOL)isIndeterminate
{
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
