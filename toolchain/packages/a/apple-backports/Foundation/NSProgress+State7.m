#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantProgressPausedKey;
static char RevenantProgressAdditionalKey;
static char RevenantProgressResumingKey;

@implementation NSProgress (RevenantState)

- (BOOL)isIndeterminate
{
    return self.totalUnitCount < 0 || self.completedUnitCount < 0 ||
           (self.totalUnitCount == 0 && self.completedUnitCount == 0);
}

- (BOOL)isPaused
{
    return [objc_getAssociatedObject(self, &RevenantProgressPausedKey) boolValue];
}

- (NSString *)localizedAdditionalDescription
{
    return objc_getAssociatedObject(self, &RevenantProgressAdditionalKey);
}

- (void)setLocalizedAdditionalDescription:(NSString *)description
{
    if (!description) {
        NSNumber *total = [self.userInfo objectForKey:NSProgressFileTotalCountKey];
        NSNumber *done = [self.userInfo objectForKey:NSProgressFileCompletedCountKey];
        if (total && done)
            description = [NSString stringWithFormat:@"%@ of %@", done, total];
    }
    objc_setAssociatedObject(self, &RevenantProgressAdditionalKey, [description copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(void))resumingHandler
{
    return objc_getAssociatedObject(self, &RevenantProgressResumingKey);
}

- (void)setResumingHandler:(void (^)(void))handler
{
    objc_setAssociatedObject(self, &RevenantProgressResumingKey, [handler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(void))revenant_progressResumingHandler
{
    return objc_getAssociatedObject(self, &RevenantProgressResumingKey);
}

- (void)resume
{
    BOOL wasPaused = self.isPaused;
    if (wasPaused)
        objc_setAssociatedObject(self, &RevenantProgressPausedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    void (^handler)(void) = [self revenant_progressResumingHandler];
    if (handler && wasPaused)
        handler();
}

@end
