#import <UIKit/UIKit.h>
#import "previewaction-cases.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *titles(NSArray *actions)
{
    NSMutableArray *found = [NSMutableArray array];
    for (id<UIPreviewActionItem> item in actions)
        [found addObject:item.title ?: @"nil"];
    return [found componentsJoinedByString:@","];
}

void previewaction_run(PreviewActionRecorder record)
{
    __block int called = 0;
    __block id seenAction = nil;
    __block id seenController = nil;
    UIViewController *controller = [[UIViewController alloc] init];
    UIPreviewAction *action = [UIPreviewAction actionWithTitle:@"Share" style:UIPreviewActionStyleSelected handler:^(UIPreviewAction *item, UIViewController *host) {
        called++;
        seenAction = item;
        seenController = host;
    }];
    record(@"action.new", [NSString stringWithFormat:@"%@ title=%@ style=%ld handler=%d", NSStringFromClass([action superclass]), action.title, (long)[[action valueForKey:@"style"] integerValue], action.handler != nil]);
    action.handler(action, controller);
    record(@"action.handler", [NSString stringWithFormat:@"called=%d action=%d controller=%d", called, seenAction == action, seenController == controller]);

    NSMutableString *title = [NSMutableString stringWithString:@"Delete"];
    UIPreviewAction *destructive = [UIPreviewAction actionWithTitle:title style:UIPreviewActionStyleDestructive handler:nil];
    [title appendString:@" all"];
    record(@"action.titleCopied", [NSString stringWithFormat:@"%@ style=%ld handler=%d", destructive.title, (long)[[destructive valueForKey:@"style"] integerValue], destructive.handler != nil]);
    record(@"action.nilTitle", [NSString stringWithFormat:@"%d", [UIPreviewAction actionWithTitle:nil style:UIPreviewActionStyleDefault handler:nil].title == nil]);

    UIPreviewAction *copy = [action copy];
    record(@"action.copy", [NSString stringWithFormat:@"same=%d title=%@ style=%ld handler=%d", copy == action, copy.title, (long)[[copy valueForKey:@"style"] integerValue], copy.handler != nil]);
    UIPreviewAction *plain = [[UIPreviewAction alloc] init];
    record(@"action.init", [NSString stringWithFormat:@"title=%d handler=%d style=%ld", plain.title == nil, plain.handler == nil, (long)[[plain valueForKey:@"style"] integerValue]]);
    record(@"action.protocols", [NSString stringWithFormat:@"item=%d copying=%d secure=%d", [action conformsToProtocol:@protocol(UIPreviewActionItem)], [action conformsToProtocol:@protocol(NSCopying)], [action conformsToProtocol:@protocol(NSSecureCoding)]]);

    NSMutableArray *members = [NSMutableArray arrayWithObjects:action, destructive, nil];
    UIPreviewActionGroup *group = [UIPreviewActionGroup actionGroupWithTitle:@"More" style:UIPreviewActionStyleDestructive actions:members];
    [members addObject:plain];
    NSArray *held = [group valueForKey:@"actions"];
    record(@"group.new", [NSString stringWithFormat:@"%@ title=%@ style=%ld actions=%@ first=%d", NSStringFromClass([group superclass]), group.title, (long)[[group valueForKey:@"style"] integerValue], titles(held), held.firstObject == action]);
    UIPreviewActionGroup *groupCopy = [group copy];
    NSArray *copied = [groupCopy valueForKey:@"actions"];
    record(@"group.copy", [NSString stringWithFormat:@"same=%d title=%@ actions=%@ shared=%d", groupCopy == group, groupCopy.title, titles(copied), copied.firstObject == action]);
    UIPreviewActionGroup *empty = [UIPreviewActionGroup actionGroupWithTitle:nil style:UIPreviewActionStyleDefault actions:nil];
    record(@"group.empty", [NSString stringWithFormat:@"title=%d actions=%lu", empty.title == nil, (unsigned long)[[empty valueForKey:@"actions"] count]]);
    record(@"group.protocols", [NSString stringWithFormat:@"item=%d copying=%d secure=%d", [group conformsToProtocol:@protocol(UIPreviewActionItem)], [group conformsToProtocol:@protocol(NSCopying)], [group conformsToProtocol:@protocol(NSSecureCoding)]]);
    record(@"controller.items", [NSString stringWithFormat:@"%lu", (unsigned long)controller.previewActionItems.count]);
    record(@"controller.itemsClass", NSStringFromClass([controller.previewActionItems class]).length ? @"array" : @"none");
}
