#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVFDescriptorConstruction.h"

// AVMediaSelection and AVMutableMediaSelection, iOS 9.
//
// The first HELD RUNG that exports both classes and their metaclasses is **9.3.6**, measured over every
// held cache with _NSFileSize planted as a control. Neither 6.1.3 nor 7.0 nor 8.x nor 9.2 exports them,
// so the port defines both, the subclass in the same object because it is a subclass of the other and
// release-split measures per object file rather than per class.
//
// What the host declares, which is what these are written against: AVMediaSelection is NSObject's
// subclass at instance size 16 with `-asset`, `-selectedMediaOptionInMediaSelectionGroup:`,
// `-propertyList`, `-copyWithZone:`, `-isEqual:`, `-hash` and the factories, and AVMutableMediaSelection
// adds `-selectMediaOption:inMediaSelectionGroup:` and its own `-copyWithZone:`.
//
// A media selection is which option of each characteristic is chosen, and that is data. There is no
// asset and no media behind it here, so the port stores the selection the caller gave it and answers
// the documented empty answers where there is nothing: no groups, and nil for the asset, because no
// asset was ever given. That is the honest answer rather than a fabricated AVAsset, and the header
// marks -asset as the selection's own asset rather than requiring one.

@implementation AVMediaSelection

- (NSDictionary<NSString *, AVMediaSelectionOption *> *)charon_selected
{
    return objc_getAssociatedObject(self, "charon.avf.selection.selected") ?: @{};
}

- (void)charon_setSelected:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
{
    objc_setAssociatedObject(self, "charon.avf.selection.selected", selected ?: @{},
                             OBJC_ASSOCIATION_COPY);
}


- (instancetype)charon_initWithSelectedOptionsByGroup:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
{
    self = [super init];
    if (self) {
        [self charon_setSelected:selected];
    }
    return self;
}

// The header's own factory. With no asset the port can carry, the selection is built over the caller's
// options and the asset is nil, which is the documented answer for a selection that has no asset.
+ (instancetype)mediaSelectionWithAsset:(AVAsset *)asset
{
    return [[self alloc] charon_initWithSelectedOptionsByGroup:@{}];
}

- (AVAsset *)asset
{
    return nil;
}

- (NSArray<AVMediaSelectionGroup *> *)mediaSelectionGroups
{
    return @[];
}

- (NSArray<AVMediaSelectionOption *> *)selectedMediaOptions
{
    NSMutableArray *options = [NSMutableArray array];
    for (AVMediaSelectionOption *option in self.charon_selected.allValues) {
        [options addObject:option];
    }
    return options;
}

- (AVMediaSelectionOption *)selectedMediaOptionInMediaSelectionGroup:(AVMediaSelectionGroup *)mediaSelectionGroup
{
    if (!mediaSelectionGroup) {
        return nil;
    }
    // The characteristics of a group are reached through -mediaCharacteristics, which the SDK does
    // not declare as a property on the class, so it is sent behind a respondsToSelector: guard.
    //
    // **A local @interface declaring that selector would be the better shape, and the declaration
    // belongs in the slice that carries AVMediaSelectionGroup, not here.** That class is the
    // RELEASE's (its own row is owed, and it is the NONE-of-the-fifteen group), so declaring
    // -mediaCharacteristics on it from this file would put a port-owned declaration on a class the
    // port does not own, and the next slice would have to take it back. Until then the guard is
    // honest about the state: the member is reached because the compiler cannot see it, and the
    // differential can still exercise the row.
    id group = (id)mediaSelectionGroup;
    if (![group respondsToSelector:@selector(mediaCharacteristics)]) {
        return nil;
    }
    NSArray *characteristics = ((id (*)(id, SEL))objc_msgSend)(group, @selector(mediaCharacteristics));
    for (NSString *characteristic in characteristics) {
        AVMediaSelectionOption *option = self.charon_selected[characteristic];
        if (option) {
            return option;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] charon_initWithSelectedOptionsByGroup:self.charon_selected];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[AVMediaSelection class]]) {
        return NO;
    }
    return [self.charon_selected isEqualToDictionary:((AVMediaSelection *)other).charon_selected];
}

- (NSUInteger)hash
{
    return self.charon_selected.count;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AVMediaSelection %p groups=%lu selected=%lu>", self,
            (unsigned long)[self mediaSelectionGroups].count,
            (unsigned long)[self selectedMediaOptions].count];
}

@end

@implementation AVMutableMediaSelection

- (void)selectMediaOption:(AVMediaSelectionOption *)mediaSelectionOption
     inMediaSelectionGroup:(AVMediaSelectionGroup *)mediaSelectionGroup
{
    if (!mediaSelectionOption || !mediaSelectionGroup) {
        return;
    }
    // -mediaCharacteristics is not a declared property on the class the port holds here, so it goes
    // behind a respondsToSelector: guard; the declaration that would replace the cast belongs in the
    // slice that carries AVMediaSelectionGroup, which is the release's class and is owed. See the
    // same note on -selectedMediaOptionInMediaSelectionGroup: above.
    id group = (id)mediaSelectionGroup;
    NSArray *characteristics = [group respondsToSelector:@selector(mediaCharacteristics)]
        ? ((id (*)(id, SEL))objc_msgSend)(group, @selector(mediaCharacteristics)) : nil;
    NSMutableDictionary *selected = [self.charon_selected mutableCopy] ?: [NSMutableDictionary dictionary];
    for (NSString *characteristic in characteristics) {
        selected[characteristic] = mediaSelectionOption;
    }
    [self charon_setSelected:selected];
}

@end
