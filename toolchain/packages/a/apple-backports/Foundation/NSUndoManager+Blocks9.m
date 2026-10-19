#import <Foundation/Foundation.h>

@interface CharonUndoBlockInvoker : NSObject
@property (copy) void (^block)(id target);
@property (weak) id target;
@end

@implementation CharonUndoBlockInvoker
@synthesize block = _block;
@synthesize target = _target;
@end

@implementation NSUndoManager (CharonUndoBlocks)

- (void)registerUndoWithTarget:(id)target handler:(void (^)(id target))undoHandler
{
    CharonUndoBlockInvoker *invoker = [CharonUndoBlockInvoker new];
    invoker.block = undoHandler;
    invoker.target = target;
    [self registerUndoWithTarget:invoker selector:@selector(charonInvoke:) object:invoker];
}

@end

@implementation CharonUndoBlockInvoker (CharonInvoke)

- (void)charonInvoke:(id)object
{
    if (self.block && self.target)
        self.block(self.target);
}

@end
