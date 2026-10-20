#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>

@interface RevenantContacts : NSObject
+ (NSArray<NSString *> *)contactKeys;
+ (ABPropertyID)propertyForKey:(NSString *)key;
+ (NSString *)keyForProperty:(ABPropertyID)property;
+ (BOOL)key:(NSString *)key holdsLabeledValues:(BOOL *)labeled;
+ (NSString *)serviceForAddressBookService:(NSString *)service;
+ (NSString *)addressBookServiceForService:(NSString *)service;
+ (NSDictionary *)addressBookAddressWithPostalAddress:(CNPostalAddress *)address;
+ (CNMutablePostalAddress *)postalAddressWithAddressBookAddress:(NSDictionary *)dictionary;
+ (NSDictionary *)addressBookProfileWithSocialProfile:(CNSocialProfile *)profile;
+ (CNSocialProfile *)socialProfileWithAddressBookProfile:(NSDictionary *)dictionary;
+ (NSDictionary *)addressBookMessageWithInstantMessageAddress:(CNInstantMessageAddress *)address;
+ (CNInstantMessageAddress *)instantMessageAddressWithAddressBookMessage:(NSDictionary *)dictionary;
+ (NSString *)digitsOfPhoneNumber:(NSString *)number;
+ (NSDateComponents *)componentsWithDate:(NSDate *)date;
+ (NSDate *)dateWithComponents:(NSDateComponents *)components;
+ (NSError *)errorWithCode:(CNErrorCode)code reason:(NSString *)reason;
@end

typedef NS_ENUM(NSInteger, RevenantContactMatch) {
    RevenantContactMatchAll,
    RevenantContactMatchName,
    RevenantContactMatchIdentifiers,
    RevenantContactMatchGroup,
    RevenantContactMatchContainer,
    RevenantContactMatchEmail,
    RevenantContactMatchPhone,
    RevenantContactMatchGroupIdentifiers,
    RevenantContactMatchGroupsInContainer,
    RevenantContactMatchContainerIdentifiers,
    RevenantContactMatchContainerOfContact,
    RevenantContactMatchContainerOfGroup
};

@interface RevenantContactPredicate : NSPredicate
+ (instancetype)predicateWithMatch:(RevenantContactMatch)match value:(id)value;
@property (readonly) RevenantContactMatch match;
@property (readonly, strong) id value;
@end

@interface RevenantContactsBook : NSObject
+ (ABAddressBookRef)createBook:(NSError **)error CF_RETURNS_RETAINED;
+ (void)watchForChanges;
+ (NSSet *)keysFromDescriptors:(NSArray *)descriptors;
+ (CNContact *)contactWithRecord:(ABRecordRef)record keys:(NSSet *)keys unify:(BOOL)unify mutable:(BOOL)mutableObjects;
+ (NSArray<CNContact *> *)contactsInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate keys:(NSSet *)keys
                                   unify:(BOOL)unify mutable:(BOOL)mutableObjects error:(NSError **)error;
+ (void)readRecord:(ABRecordRef)record into:(NSMutableDictionary *)values keys:(NSSet *)keys filling:(BOOL)filling;
+ (ABRecordRef)createRecordWithContact:(CNContact *)contact CF_RETURNS_RETAINED;
+ (BOOL)applyContact:(CNContact *)contact toRecord:(ABRecordRef)record error:(NSError **)error;
+ (NSString *)compositeNameOfContact:(CNContact *)contact;
+ (BOOL)contactFitsTheBook:(CNContact *)contact error:(NSError **)error;
+ (CNGroup *)groupWithRecord:(ABRecordRef)record mutable:(BOOL)mutableObjects;
+ (NSArray<CNGroup *> *)groupsInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate
                              mutable:(BOOL)mutableObjects error:(NSError **)error;
+ (CNContainerType)typeOfSource:(ABRecordRef)source;
+ (CNContainer *)containerWithRecord:(ABRecordRef)source;
+ (NSArray<CNContainer *> *)containersInBook:(ABAddressBookRef)book matching:(NSPredicate *)predicate error:(NSError **)error;
+ (ABRecordRef)sourceOfPersonWithIdentifier:(NSString *)identifier inBook:(ABAddressBookRef)book CF_RETURNS_NOT_RETAINED;
+ (ABRecordRef)sourceOfGroupWithIdentifier:(NSString *)identifier inBook:(ABAddressBookRef)book CF_RETURNS_NOT_RETAINED;
@end

@interface RevenantContactsKeyDescriptor : NSObject <CNKeyDescriptor>
+ (instancetype)descriptorWithKeys:(NSArray<NSString *> *)keys;
@property (readonly, copy) NSArray<NSString *> *keys;
@end

@interface CNContact (Revenant)
- (id)revenant_valueForContactKey:(NSString *)key;
- (void)revenant_setValue:(id)value forContactKey:(NSString *)key;
- (NSDictionary *)revenant_values;
- (void)revenant_setValues:(NSDictionary *)values available:(NSSet *)keys identifier:(NSString *)identifier;
- (NSSet *)revenant_availableKeys;
- (NSArray<NSString *> *)revenant_linkedIdentifiers;
- (void)revenant_setLinkedIdentifiers:(NSArray<NSString *> *)identifiers;
@end

@interface CNSaveRequest (Revenant)
- (NSArray *)revenant_added;
- (NSArray *)revenant_updated;
- (NSArray *)revenant_deleted;
- (NSArray *)revenant_addedGroups;
- (NSArray *)revenant_updatedGroups;
- (NSArray *)revenant_deletedGroups;
- (NSArray *)revenant_addedMembers;
- (NSArray *)revenant_removedMembers;
@end

@interface CNGroup (Revenant)
+ (instancetype)revenant_groupWithIdentifier:(NSString *)identifier name:(NSString *)name mutable:(BOOL)mutableObjects;
- (void)revenant_setIdentifier:(NSString *)identifier name:(NSString *)name;
@end

@interface CNFetchResult (Revenant)
+ (instancetype)revenant_resultWithValue:(id)value historyToken:(NSData *)token;
@end

@interface CNContainer (Revenant)
+ (instancetype)revenant_containerWithIdentifier:(NSString *)identifier name:(NSString *)name type:(CNContainerType)type;
@end

@interface CNContactStore (Revenant)
- (NSArray *)revenant_contactsMatching:(NSPredicate *)predicate keysToFetch:(NSArray *)keys unify:(BOOL)unify
                             mutable:(BOOL)mutableObjects sortOrder:(CNContactSortOrder)sortOrder error:(NSError **)error;
@end

@interface RevenantContactsHistory : NSObject
+ (NSData *)currentToken;
+ (CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *)enumeratorForRequest:(CNChangeHistoryFetchRequest *)request error:(NSError **)error;
@end

@interface CNChangeHistoryAddContactEvent (Revenant)
+ (instancetype)revenant_eventWithContact:(CNContact *)contact containerIdentifier:(NSString *)containerIdentifier;
@end

@interface CNChangeHistoryUpdateContactEvent (Revenant)
+ (instancetype)revenant_eventWithContact:(CNContact *)contact;
@end

@interface CNChangeHistoryDeleteContactEvent (Revenant)
+ (instancetype)revenant_eventWithContactIdentifier:(NSString *)identifier;
@end

@interface CNChangeHistoryAddGroupEvent (Revenant)
+ (instancetype)revenant_eventWithGroup:(CNGroup *)group containerIdentifier:(NSString *)containerIdentifier;
@end

@interface CNChangeHistoryUpdateGroupEvent (Revenant)
+ (instancetype)revenant_eventWithGroup:(CNGroup *)group;
@end

@interface CNChangeHistoryDeleteGroupEvent (Revenant)
+ (instancetype)revenant_eventWithGroupIdentifier:(NSString *)identifier;
@end

@interface CNChangeHistoryAddMemberToGroupEvent (Revenant)
+ (instancetype)revenant_eventWithMember:(CNContact *)member group:(CNGroup *)group;
@end

@interface CNChangeHistoryRemoveMemberFromGroupEvent (Revenant)
+ (instancetype)revenant_eventWithMember:(CNContact *)member group:(CNGroup *)group;
@end

@interface CNPostalAddress (Revenant)
- (NSString *)revenant_fieldForKey:(NSString *)key;
- (void)revenant_setField:(NSString *)value forKey:(NSString *)key;
- (NSDictionary *)revenant_fields;
@end

@interface CNLabeledValue (Revenant)
+ (instancetype)revenant_labeledValueWithLabel:(NSString *)label value:(id)value identifier:(ABMultiValueIdentifier)identifier;
- (ABMultiValueIdentifier)revenant_addressBookIdentifier;
@end
