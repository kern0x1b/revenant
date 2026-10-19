#import "CharonContacts.h"

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
    // The protocol is asked for before the event is handed over, so the protocol object is one this
    // library carries and a visitor that does not adopt it is not sent a message it does not have.
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitDropEverythingEvent:self];
    }
}

@end

@implementation CNChangeHistoryAddContactEvent {
    CNContact *_charonContact;
    NSString *_charonContainerIdentifier;
}

@dynamic contact, containerIdentifier;

+ (instancetype)charon_eventWithContact:(CNContact *)contact containerIdentifier:(NSString *)containerIdentifier
{
    CNChangeHistoryAddContactEvent *event = [[self alloc] init];
    event->_charonContact = contact;
    event->_charonContainerIdentifier = [containerIdentifier copy];
    return event;
}

- (CNContact *)contact { return _charonContact; }
- (NSString *)containerIdentifier { return _charonContainerIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    // The protocol is asked for before the event is handed over, so the protocol object is one this
    // library carries and a visitor that does not adopt it is not sent a message it does not have.
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitAddContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryUpdateContactEvent {
    CNContact *_charonContact;
}

@dynamic contact;

+ (instancetype)charon_eventWithContact:(CNContact *)contact
{
    CNChangeHistoryUpdateContactEvent *event = [[self alloc] init];
    event->_charonContact = contact;
    return event;
}

- (CNContact *)contact { return _charonContact; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    // The protocol is asked for before the event is handed over, so the protocol object is one this
    // library carries and a visitor that does not adopt it is not sent a message it does not have.
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitUpdateContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryDeleteContactEvent {
    NSString *_charonContactIdentifier;
}

@dynamic contactIdentifier;

+ (instancetype)charon_eventWithContactIdentifier:(NSString *)identifier
{
    CNChangeHistoryDeleteContactEvent *event = [[self alloc] init];
    event->_charonContactIdentifier = [identifier copy];
    return event;
}

- (NSString *)contactIdentifier { return _charonContactIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    // The protocol is asked for before the event is handed over, so the protocol object is one this
    // library carries and a visitor that does not adopt it is not sent a message it does not have.
    if ([visitor conformsToProtocol:@protocol(CNChangeHistoryEventVisitor)]) {
        [visitor visitDeleteContactEvent:self];
    }
}

@end

@implementation CNChangeHistoryAddGroupEvent {
    CNGroup *_charonGroup;
    NSString *_charonContainerIdentifier;
}

@dynamic group, containerIdentifier;

+ (instancetype)charon_eventWithGroup:(CNGroup *)group containerIdentifier:(NSString *)containerIdentifier
{
    CNChangeHistoryAddGroupEvent *event = [[self alloc] init];
    event->_charonGroup = group;
    event->_charonContainerIdentifier = [containerIdentifier copy];
    return event;
}

- (CNGroup *)group { return _charonGroup; }
- (NSString *)containerIdentifier { return _charonContainerIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddGroupEvent:)])
        [visitor visitAddGroupEvent:self];
}

@end

@implementation CNChangeHistoryUpdateGroupEvent {
    CNGroup *_charonGroup;
}

@dynamic group;

+ (instancetype)charon_eventWithGroup:(CNGroup *)group
{
    CNChangeHistoryUpdateGroupEvent *event = [[self alloc] init];
    event->_charonGroup = group;
    return event;
}

- (CNGroup *)group { return _charonGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitUpdateGroupEvent:)])
        [visitor visitUpdateGroupEvent:self];
}

@end

@implementation CNChangeHistoryDeleteGroupEvent {
    NSString *_charonGroupIdentifier;
}

@dynamic groupIdentifier;

+ (instancetype)charon_eventWithGroupIdentifier:(NSString *)identifier
{
    CNChangeHistoryDeleteGroupEvent *event = [[self alloc] init];
    event->_charonGroupIdentifier = [identifier copy];
    return event;
}

- (NSString *)groupIdentifier { return _charonGroupIdentifier; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitDeleteGroupEvent:)])
        [visitor visitDeleteGroupEvent:self];
}

@end

@implementation CNChangeHistoryAddMemberToGroupEvent {
    CNContact *_charonMember;
    CNGroup *_charonGroup;
}

@dynamic member, group;

+ (instancetype)charon_eventWithMember:(CNContact *)member group:(CNGroup *)group
{
    CNChangeHistoryAddMemberToGroupEvent *event = [[self alloc] init];
    event->_charonMember = member;
    event->_charonGroup = group;
    return event;
}

- (CNContact *)member { return _charonMember; }
- (CNGroup *)group { return _charonGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddMemberToGroupEvent:)])
        [visitor visitAddMemberToGroupEvent:self];
}

@end

@implementation CNChangeHistoryRemoveMemberFromGroupEvent {
    CNContact *_charonMember;
    CNGroup *_charonGroup;
}

@dynamic member, group;

+ (instancetype)charon_eventWithMember:(CNContact *)member group:(CNGroup *)group
{
    CNChangeHistoryRemoveMemberFromGroupEvent *event = [[self alloc] init];
    event->_charonMember = member;
    event->_charonGroup = group;
    return event;
}

- (CNContact *)member { return _charonMember; }
- (CNGroup *)group { return _charonGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitRemoveMemberFromGroupEvent:)])
        [visitor visitRemoveMemberFromGroupEvent:self];
}

@end

@implementation CNChangeHistoryAddSubgroupToGroupEvent {
    CNGroup *_charonSubgroup;
    CNGroup *_charonGroup;
}

@dynamic subgroup, group;

- (CNGroup *)subgroup { return _charonSubgroup; }
- (CNGroup *)group { return _charonGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitAddSubgroupToGroupEvent:)])
        [visitor visitAddSubgroupToGroupEvent:self];
}

@end

@implementation CNChangeHistoryRemoveSubgroupFromGroupEvent {
    CNGroup *_charonSubgroup;
    CNGroup *_charonGroup;
}

@dynamic subgroup, group;

- (CNGroup *)subgroup { return _charonSubgroup; }
- (CNGroup *)group { return _charonGroup; }

- (void)acceptEventVisitor:(id<CNChangeHistoryEventVisitor>)visitor
{
    if ([visitor respondsToSelector:@selector(visitRemoveSubgroupFromGroupEvent:)])
        [visitor visitRemoveSubgroupFromGroupEvent:self];
}

@end
