#ifdef __OBJC__

static inline void RevenantMetalPushDebugGroup(NSMutableArray *groups, NSString *name)
{
    [groups addObject:name ? name : @""];
}

static inline void RevenantMetalPopDebugGroup(NSMutableArray *groups, id owner)
{
    if (groups.count) {
        [groups removeLastObject];
        return;
    }
    NSLog(@"Metal: a debug group was popped on a %@ and none was pushed", NSStringFromClass([owner class]));
}

#endif
