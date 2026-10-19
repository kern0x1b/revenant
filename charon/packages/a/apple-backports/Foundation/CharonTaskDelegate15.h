#import <Foundation/Foundation.h>

/* The one thing NSURLSession.m needs from the per-task delegate that is not the delegate itself.

   The header's rule is that the delegate is kept alive until the task completes, and then
   is reset to nil (SDK 16.4 NSURLSession.h:303-304), and the reset has to happen where
   the completion is delivered. It cannot go through -setDelegate:, because that now refuses a task
   that has resumed and a task being completed has resumed - so the storage is cleared directly, and
   this is the seam that does it. It is the same shape as CharonURLSessionMetrics.h's note calls: a
   method the loader itself calls, on the class that owns the state, declared in a header both files
   read so the call and the definition cannot disagree about its name.

   Declared on NSURLSessionTask rather than in the category so the declaration does not depend on
   which category is compiled in; the definition is in NSURLSessionTask+Delegate15.m, beside the
   accessors whose storage it clears. */
@interface NSURLSessionTask (CharonTaskDelegateReset)
- (void)charon_resetTaskDelegate;
@end
