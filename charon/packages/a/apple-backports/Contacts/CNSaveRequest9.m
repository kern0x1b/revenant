#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNSaveRequest {
    NSMutableArray *_charonAdded;
    NSMutableArray *_charonUpdated;
    NSMutableArray *_charonDeleted;
    NSMutableArray *_charonAddedGroups;
    NSMutableArray *_charonUpdatedGroups;
    NSMutableArray *_charonDeletedGroups;
    NSMutableArray *_charonAddedMembers;
    NSMutableArray *_charonRemovedMembers;
}

@synthesize transactionAuthor = _charonTransactionAuthor;
@synthesize shouldRefetchContacts = _charonShouldRefetchContacts;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _charonAdded = [NSMutableArray array];
        _charonUpdated = [NSMutableArray array];
        _charonDeleted = [NSMutableArray array];
        _charonAddedGroups = [NSMutableArray array];
        _charonUpdatedGroups = [NSMutableArray array];
        _charonDeletedGroups = [NSMutableArray array];
        _charonAddedMembers = [NSMutableArray array];
        _charonRemovedMembers = [NSMutableArray array];
    }
    return self;
}

- (void)addContact:(CNMutableContact *)contact toContainerWithIdentifier:(NSString *)identifier
{
    if (contact)
        [_charonAdded addObject:@[contact, identifier ?: @""]];
}

- (void)updateContact:(CNMutableContact *)contact
{
    if (contact)
        [_charonUpdated addObject:contact];
}

- (void)deleteContact:(CNMutableContact *)contact
{
    if (contact)
        [_charonDeleted addObject:contact];
}

- (void)addGroup:(CNMutableGroup *)group toContainerWithIdentifier:(NSString *)identifier
{
    if (group)
        [_charonAddedGroups addObject:@[group, identifier ?: @""]];
}

- (void)updateGroup:(CNMutableGroup *)group
{
    if (group)
        [_charonUpdatedGroups addObject:group];
}

- (void)deleteGroup:(CNMutableGroup *)group
{
    if (group)
        [_charonDeletedGroups addObject:group];
}

- (void)addMember:(CNContact *)contact toGroup:(CNGroup *)group
{
    if (contact && group)
        [_charonAddedMembers addObject:@[contact, group]];
}

- (void)removeMember:(CNContact *)contact fromGroup:(CNGroup *)group
{
    if (contact && group)
        [_charonRemovedMembers addObject:@[contact, group]];
}

- (NSArray *)charon_added { return _charonAdded; }
- (NSArray *)charon_updated { return _charonUpdated; }
- (NSArray *)charon_deleted { return _charonDeleted; }
- (NSArray *)charon_addedGroups { return _charonAddedGroups; }
- (NSArray *)charon_updatedGroups { return _charonUpdatedGroups; }
- (NSArray *)charon_deletedGroups { return _charonDeletedGroups; }
- (NSArray *)charon_addedMembers { return _charonAddedMembers; }
- (NSArray *)charon_removedMembers { return _charonRemovedMembers; }

@end
