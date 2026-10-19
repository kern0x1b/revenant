// CharonMetalDebugGroups.h - the debug groups every encoder and command buffer of the port keeps, in one place.
//
// A debug group names a span of commands for a capture. Metal records the stack for the capture tool, and no
// capture runs on a device, so the port keeps the stack only to balance it: a push adds a name, a pop removes
// the innermost one. A pop with nothing open is a mistake in the caller that a capture would show; the port has
// no capture, so it says so in the log, once per call. This is a private header of the package, included by the
// files that keep a stack, so the three kinds of encoder and the command buffer behave alike.
#ifdef __OBJC__

static inline void CharonMetalPushDebugGroup(NSMutableArray *groups, NSString *name)
{
    [groups addObject:name ? name : @""];
}

static inline void CharonMetalPopDebugGroup(NSMutableArray *groups, id owner)
{
    if (groups.count) {
        [groups removeLastObject];
        return;
    }
    NSLog(@"Metal: a debug group was popped on a %@ and none was pushed", NSStringFromClass([owner class]));
}

#endif
