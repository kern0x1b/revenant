#import <UIKit/UIKit.h>

@implementation UITextDropProposal {
@private
    UITextDropAction _dropAction;
    UITextDropProgressMode _dropProgressMode;
    BOOL _useFastSameViewOperations;
    UITextDropPerformer _dropPerformer;
}

- (instancetype)initWithDropOperation:(UIDropOperation)operation
{
    if ((self = [super initWithDropOperation:operation])) {
        self.precise = YES;
        _dropAction = UITextDropActionInsert;
        _useFastSameViewOperations = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    UITextDropProposal *copy = [super copyWithZone:zone];
    copy.dropAction = self.dropAction;
    copy.useFastSameViewOperations = self.useFastSameViewOperations;
    copy.dropProgressMode = self.dropProgressMode;
    copy.dropPerformer = self.dropPerformer;
    return copy;
}

- (UITextDropAction)dropAction
{
    return _dropAction;
}

- (void)setDropAction:(UITextDropAction)dropAction
{
    _dropAction = dropAction;
}

- (UITextDropProgressMode)dropProgressMode
{
    return _dropProgressMode;
}

- (void)setDropProgressMode:(UITextDropProgressMode)dropProgressMode
{
    _dropProgressMode = dropProgressMode;
}

- (BOOL)useFastSameViewOperations
{
    return _useFastSameViewOperations;
}

- (void)setUseFastSameViewOperations:(BOOL)useFastSameViewOperations
{
    _useFastSameViewOperations = useFastSameViewOperations;
}

- (UITextDropPerformer)dropPerformer
{
    return _dropPerformer;
}

- (void)setDropPerformer:(UITextDropPerformer)dropPerformer
{
    _dropPerformer = dropPerformer;
}

@end
