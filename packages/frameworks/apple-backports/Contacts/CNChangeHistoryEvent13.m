#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNChangeHistoryEvent

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation CNChangeHistoryDropEverythingEvent

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitDropEverythingEvent:self];
    }
}

@end

@implementation CNChangeHistoryAddContactEvent {
    CNContact *_revenantContact;
    NSString *_revenantContainerIdentifier;
}

@dynamic contact, containerIdentifier;

+ (instancetype)revenant_eventWithContact:(CNContact *)contact containerIdentifier:(NSString *)containerIdentifier
{
    CNChangeHistoryAddContactEvent *event = [[self alloc] init];
    event->_revenantContact = contact;
    event->_revenantContainerIdentifier = [containerIdentifier copy];
    return event;
}

- (CNContact *)contact { return _revenantContact; }
- (NSString *)containerIdentifier { return _revenantContainerIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitAddContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryUpdateContactEvent {
    CNContact *_revenantContact;
}

@dynamic contact;

+ (instancetype)revenant_eventWithContact:(CNContact *)contact
{
    CNChangeHistoryUpdateContactEvent *event = [[self alloc] init];
    event->_revenantContact = contact;
    return event;
}

- (CNContact *)contact { return _revenantContact; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitUpdateContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryDeleteContactEvent {
    NSString *_revenantContactIdentifier;
}

@dynamic contactIdentifier;

+ (instancetype)revenant_eventWithContactIdentifier:(NSString *)identifier
{
    CNChangeHistoryDeleteContactEvent *event = [[self alloc] init];
    event->_revenantContactIdentifier = [identifier copy];
    return event;
}

- (NSString *)contactIdentifier { return _revenantContactIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitDeleteContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryAddGroupEvent {
    CNGroup *_revenantGroup;
    NSString *_revenantContainerIdentifier;
}

@dynamic group, containerIdentifier;

+ (instancetype)revenant_eventWithGroup:(CNGroup *)group containerIdentifier:(NSString *)containerIdentifier
{
    CNChangeHistoryAddGroupEvent *event = [[self alloc] init];
    event->_revenantGroup = group;
    event->_revenantContainerIdentifier = [containerIdentifier copy];
    return event;
}

- (CNGroup *)group { return _revenantGroup; }
- (NSString *)containerIdentifier { return _revenantContainerIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddGroupEvent:)])
        [visitor visitAddGroupEvent:self];
}

@end

@implementation CNChangeHistoryUpdateGroupEvent {
    CNGroup *_revenantGroup;
}

@dynamic group;

+ (instancetype)revenant_eventWithGroup:(CNGroup *)group
{
    CNChangeHistoryUpdateGroupEvent *event = [[self alloc] init];
    event->_revenantGroup = group;
    return event;
}

- (CNGroup *)group { return _revenantGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitUpdateGroupEvent:)])
        [visitor visitUpdateGroupEvent:self];
}

@end

@implementation CNChangeHistoryDeleteGroupEvent {
    NSString *_revenantGroupIdentifier;
}

@dynamic groupIdentifier;

+ (instancetype)revenant_eventWithGroupIdentifier:(NSString *)identifier
{
    CNChangeHistoryDeleteGroupEvent *event = [[self alloc] init];
    event->_revenantGroupIdentifier = [identifier copy];
    return event;
}

- (NSString *)groupIdentifier { return _revenantGroupIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitDeleteGroupEvent:)])
        [visitor visitDeleteGroupEvent:self];
}

@end

@implementation CNChangeHistoryAddMemberToGroupEvent {
    CNContact *_revenantMember;
    CNGroup *_revenantGroup;
}

@dynamic member, group;

+ (instancetype)revenant_eventWithMember:(CNContact *)member group:(CNGroup *)group
{
    CNChangeHistoryAddMemberToGroupEvent *event = [[self alloc] init];
    event->_revenantMember = member;
    event->_revenantGroup = group;
    return event;
}

- (CNContact *)member { return _revenantMember; }
- (CNGroup *)group { return _revenantGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddMemberToGroupEvent:)])
        [visitor visitAddMemberToGroupEvent:self];
}

@end

@implementation CNChangeHistoryRemoveMemberFromGroupEvent {
    CNContact *_revenantMember;
    CNGroup *_revenantGroup;
}

@dynamic member, group;

+ (instancetype)revenant_eventWithMember:(CNContact *)member group:(CNGroup *)group
{
    CNChangeHistoryRemoveMemberFromGroupEvent *event = [[self alloc] init];
    event->_revenantMember = member;
    event->_revenantGroup = group;
    return event;
}

- (CNContact *)member { return _revenantMember; }
- (CNGroup *)group { return _revenantGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitRemoveMemberFromGroupEvent:)])
        [visitor visitRemoveMemberFromGroupEvent:self];
}

@end

@implementation CNChangeHistoryAddSubgroupToGroupEvent {
    CNGroup *_revenantSubgroup;
    CNGroup *_revenantGroup;
}

@dynamic subgroup, group;

- (CNGroup *)subgroup { return _revenantSubgroup; }
- (CNGroup *)group { return _revenantGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddSubgroupToGroupEvent:)])
        [visitor visitAddSubgroupToGroupEvent:self];
}

@end

@implementation CNChangeHistoryRemoveSubgroupFromGroupEvent {
    CNGroup *_revenantSubgroup;
    CNGroup *_revenantGroup;
}

@dynamic subgroup, group;

- (CNGroup *)subgroup { return _revenantSubgroup; }
- (CNGroup *)group { return _revenantGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitRemoveSubgroupFromGroupEvent:)])
        [visitor visitRemoveSubgroupFromGroupEvent:self];
}

@end
