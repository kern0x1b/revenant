#import <Foundation/Foundation.h>

@interface RevenantUndoBlockInvoker : NSObject
@property (copy) void (^block)(id target);
@property (weak) id target;
@end

@implementation RevenantUndoBlockInvoker
@synthesize block = _block;
@synthesize target = _target;
@end

@implementation NSUndoManager (RevenantUndoBlocks)

- (void)registerUndoWithTarget:(id)target handler:(void (^)(id target))undoHandler
{
    RevenantUndoBlockInvoker *invoker = [RevenantUndoBlockInvoker new];
    invoker.block = undoHandler;
    invoker.target = target;
    [self registerUndoWithTarget:invoker selector:@selector(revenantInvoke:) object:invoker];
}

@end

@implementation RevenantUndoBlockInvoker (RevenantInvoke)

- (void)revenantInvoke:(id)object
{
    if (self.block && self.target)
        self.block(self.target);
}

@end
