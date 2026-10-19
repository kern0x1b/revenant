#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNSaveRequest {
    NSMutableArray *_revenantAdded;
    NSMutableArray *_revenantUpdated;
    NSMutableArray *_revenantDeleted;
    NSMutableArray *_revenantAddedGroups;
    NSMutableArray *_revenantUpdatedGroups;
    NSMutableArray *_revenantDeletedGroups;
    NSMutableArray *_revenantAddedMembers;
    NSMutableArray *_revenantRemovedMembers;
}

@synthesize transactionAuthor = _revenantTransactionAuthor;
@synthesize shouldRefetchContacts = _revenantShouldRefetchContacts;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _revenantAdded = [NSMutableArray array];
        _revenantUpdated = [NSMutableArray array];
        _revenantDeleted = [NSMutableArray array];
        _revenantAddedGroups = [NSMutableArray array];
        _revenantUpdatedGroups = [NSMutableArray array];
        _revenantDeletedGroups = [NSMutableArray array];
        _revenantAddedMembers = [NSMutableArray array];
        _revenantRemovedMembers = [NSMutableArray array];
    }
    return self;
}

- (void)addContact:(CNMutableContact *)contact toContainerWithIdentifier:(NSString *)identifier
{
    if (contact)
        [_revenantAdded addObject:@[contact, identifier ?: @""]];
}

- (void)updateContact:(CNMutableContact *)contact
{
    if (contact)
        [_revenantUpdated addObject:contact];
}

- (void)deleteContact:(CNMutableContact *)contact
{
    if (contact)
        [_revenantDeleted addObject:contact];
}

- (void)addGroup:(CNMutableGroup *)group toContainerWithIdentifier:(NSString *)identifier
{
    if (group)
        [_revenantAddedGroups addObject:@[group, identifier ?: @""]];
}

- (void)updateGroup:(CNMutableGroup *)group
{
    if (group)
        [_revenantUpdatedGroups addObject:group];
}

- (void)deleteGroup:(CNMutableGroup *)group
{
    if (group)
        [_revenantDeletedGroups addObject:group];
}

- (void)addMember:(CNContact *)contact toGroup:(CNGroup *)group
{
    if (contact && group)
        [_revenantAddedMembers addObject:@[contact, group]];
}

- (void)removeMember:(CNContact *)contact fromGroup:(CNGroup *)group
{
    if (contact && group)
        [_revenantRemovedMembers addObject:@[contact, group]];
}

- (NSArray *)revenant_added { return _revenantAdded; }
- (NSArray *)revenant_updated { return _revenantUpdated; }
- (NSArray *)revenant_deleted { return _revenantDeleted; }
- (NSArray *)revenant_addedGroups { return _revenantAddedGroups; }
- (NSArray *)revenant_updatedGroups { return _revenantUpdatedGroups; }
- (NSArray *)revenant_deletedGroups { return _revenantDeletedGroups; }
- (NSArray *)revenant_addedMembers { return _revenantAddedMembers; }
- (NSArray *)revenant_removedMembers { return _revenantRemovedMembers; }

@end
