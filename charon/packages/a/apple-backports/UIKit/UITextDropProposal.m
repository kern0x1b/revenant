#import <UIKit/UIKit.h>

// The proposal a text drop delegate is handed back, and the one CharonTextDropRequest holds and
// UITextView+TextDragDrop11.m stores the delegate's answer in. The release has no text drop to make
// one for and no class of that name at all; the port asks for one anyway, so it supplies the object.
// Behaviour read out of the 11.0 arm64 cache, not out of the header's prose: the initializer calls
// the superclass's, and on a non-nil result sets precise, the action and the fast-same-view flag,
// leaving the progress mode and the performer at zero. The copy copies all four over the superclass's.

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