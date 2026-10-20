#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVFDescriptorConstruction.h"

@implementation AVMediaSelection

- (NSDictionary<NSString *, AVMediaSelectionOption *> *)revenant_selected
{
    return objc_getAssociatedObject(self, "revenant.avf.selection.selected") ?: @{};
}

- (void)revenant_setSelected:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
{
    objc_setAssociatedObject(self, "revenant.avf.selection.selected", selected ?: @{},
                             OBJC_ASSOCIATION_COPY);
}


- (instancetype)revenant_initWithSelectedOptionsByGroup:(NSDictionary<NSString *, AVMediaSelectionOption *> *)selected
{
    self = [super init];
    if (self) {
        [self revenant_setSelected:selected];
    }
    return self;
}

+ (instancetype)mediaSelectionWithAsset:(AVAsset *)asset
{
    return [[self alloc] revenant_initWithSelectedOptionsByGroup:@{}];
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
    for (AVMediaSelectionOption *option in self.revenant_selected.allValues) {
        [options addObject:option];
    }
    return options;
}

- (AVMediaSelectionOption *)selectedMediaOptionInMediaSelectionGroup:(AVMediaSelectionGroup *)mediaSelectionGroup
{
    if (!mediaSelectionGroup) {
        return nil;
    }
    id group = (id)mediaSelectionGroup;
    if (![group respondsToSelector:@selector(mediaCharacteristics)]) {
        return nil;
    }
    NSArray *characteristics = ((id (*)(id, SEL))objc_msgSend)(group, @selector(mediaCharacteristics));
    for (NSString *characteristic in characteristics) {
        AVMediaSelectionOption *option = self.revenant_selected[characteristic];
        if (option) {
            return option;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] revenant_initWithSelectedOptionsByGroup:self.revenant_selected];
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[AVMediaSelection class]]) {
        return NO;
    }
    return [self.revenant_selected isEqualToDictionary:((AVMediaSelection *)other).revenant_selected];
}

- (NSUInteger)hash
{
    return self.revenant_selected.count;
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
    id group = (id)mediaSelectionGroup;
    NSArray *characteristics = [group respondsToSelector:@selector(mediaCharacteristics)]
        ? ((id (*)(id, SEL))objc_msgSend)(group, @selector(mediaCharacteristics)) : nil;
    NSMutableDictionary *selected = [self.revenant_selected mutableCopy] ?: [NSMutableDictionary dictionary];
    for (NSString *characteristic in characteristics) {
        selected[characteristic] = mediaSelectionOption;
    }
    [self revenant_setSelected:selected];
}

@end
