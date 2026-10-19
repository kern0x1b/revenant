#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "CharonTaskDelegate15.h"

/* The per-task delegate of iOS 15.0.

   NSURLSessionTask's -delegate is the one delegate a caller sets on a task rather than on a session, and
   a task that has one is sent the task-scoped messages instead of the session's. The class already
   declares the property (@dynamic delegate, in NSURLSession.m) and nothing implemented it, so a task
   answered the accessor with doesNotRecognizeSelector:.

   The accessors are the value in an associated object, the way NSURLSessionTask+Priority.m keeps that
   property's: a category cannot add an ivar, and the SDK's own declaration of the property is
   (nullable, retain), so the association retains. The messages are the other half and are not the
   accessors' business, so they are read through charon_task_delegate() in NSURLSession.m, which every
   task-scoped send there asks before the session's own delegate.

   Measured against the system's own Foundation by tests/backports/host/attributed15/run.sh, where the
   port's accessors and the system's answer beside each other: a fresh task has no delegate of its own
   although its session has one, a delegate set on the task reads back, and it is held for as long as
   the caller holds it and not longer.

   Three more facts about this property were measured the same way before they were written -
   tests/backports/host/tasksession/run.sh, asking the system's own NSURLSession - and on macOS 27.0
   build 26A428 arm64 the system answered all three:

     - forwarding is PER SELECTOR, not per object. A task delegate implementing nothing of the
       protocol left the session delegate hearing URLSession:task:didCompleteWithError: once; a task
       delegate implementing exactly that selector heard it once and the session delegate heard it
       zero times. So the port asks the task's delegate only for the selector being sent, which is
       what charon_task_delegate() in NSURLSession.m now does - it takes the selector and falls
       through when the task's delegate does not answer it. Before, it returned the task's delegate
       whole, so a caller that set one and implemented nothing heard nothing at all.
     - -setDelegate: after -resume is refused, not accepted: NSGenericException, "Cannot set task
       delegate after resumption". The port raises the same name with the same reason, because the
       header's "cannot be modified" is that sentence and a caller that catches it catches what the
       system throws.
     - the delegate reads nil once the task has completed, in both runs. The port resets it where
       the completion is delivered, in NSURLSession.m's completion path.

   What is NOT measured here, and is not claimed: the port's own objects are armv7 iOS 6.1.3 and no
   macOS process can load them, so each rule's presence in the port is proven by its compile and by
   the registry's row, and its runtime behaviour is what a device run decides. */

static char CharonTaskDelegateKey;

@implementation NSURLSessionTask (CharonTaskDelegate15)

- (id<NSURLSessionTaskDelegate>)delegate
{
    return objc_getAssociatedObject(self, &CharonTaskDelegateKey);
}

- (void)setDelegate:(id<NSURLSessionTaskDelegate>)delegate
{
    /* The header's "Cannot be modified after task resumes", as the system words it. -state is the
       task's own, so this asks the task rather than the session: a task resumed by any route is in
       the running state, and NSURLSessionTaskStateSuspended is the state a task created but not yet
       resumed is in, which is the case the header leaves open. Canceling and completed are past
       resume too, and the system refuses the same way there - measured, and the message is the
       system's own so a caller that matches on it matches on the system's. */
    if (self.state != NSURLSessionTaskStateSuspended) {
        [NSException raise:NSGenericException
                    format:@"Cannot set task delegate after resumption"];
    }
    objc_setAssociatedObject(self, &CharonTaskDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)charon_resetTaskDelegate
{
    /* The header's "after which it is reset to `nil`", measured on the system's own NSURLSession:
       -delegate read nil once the completion had been delivered. Clearing the association rather
       than setting it to nil is the same thing - an association with no object reads nil through the
       same accessor - and it does not go through -setDelegate:, which refuses a task that has
       resumed and this is a task that has completed. */
    objc_setAssociatedObject(self, &CharonTaskDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
