#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>

@interface CharonContacts : NSObject
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

typedef NS_ENUM(NSInteger, CharonContactMatch) {
    CharonContactMatchAll,
    CharonContactMatchName,
    CharonContactMatchIdentifiers,
    CharonContactMatchGroup,
    CharonContactMatchContainer,
    CharonContactMatchEmail,
    CharonContactMatchPhone,
    CharonContactMatchGroupIdentifiers,
    CharonContactMatchGroupsInContainer,
    CharonContactMatchContainerIdentifiers,
    CharonContactMatchContainerOfContact,
    CharonContactMatchContainerOfGroup
};

@interface CharonContactPredicate : NSPredicate
+ (instancetype)predicateWithMatch:(CharonContactMatch)match value:(id)value;
@property (readonly) CharonContactMatch match;
@property (readonly, strong) id value;
@end

@interface CharonContactsBook : NSObject
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

@interface CharonContactsKeyDescriptor : NSObject <CNKeyDescriptor>
+ (instancetype)descriptorWithKeys:(NSArray<NSString *> *)keys;
@property (readonly, copy) NSArray<NSString *> *keys;
@end

@interface CNContact (Charon)
- (id)charon_valueForContactKey:(NSString *)key;
- (void)charon_setValue:(id)value forContactKey:(NSString *)key;
- (NSDictionary *)charon_values;
- (void)charon_setValues:(NSDictionary *)values available:(NSSet *)keys identifier:(NSString *)identifier;
- (NSSet *)charon_availableKeys;
- (NSArray<NSString *> *)charon_linkedIdentifiers;
- (void)charon_setLinkedIdentifiers:(NSArray<NSString *> *)identifiers;
@end

@interface CNSaveRequest (Charon)
- (NSArray *)charon_added;
- (NSArray *)charon_updated;
- (NSArray *)charon_deleted;
- (NSArray *)charon_addedGroups;
- (NSArray *)charon_updatedGroups;
- (NSArray *)charon_deletedGroups;
- (NSArray *)charon_addedMembers;
- (NSArray *)charon_removedMembers;
@end

@interface CNGroup (Charon)
+ (instancetype)charon_groupWithIdentifier:(NSString *)identifier name:(NSString *)name mutable:(BOOL)mutableObjects;
- (void)charon_setIdentifier:(NSString *)identifier name:(NSString *)name;
@end

@interface CNFetchResult (Charon)
+ (instancetype)charon_resultWithValue:(id)value historyToken:(NSData *)token;
@end

@interface CNContainer (Charon)
+ (instancetype)charon_containerWithIdentifier:(NSString *)identifier name:(NSString *)name type:(CNContainerType)type;
@end

@interface CNContactStore (Charon)
- (NSArray *)charon_contactsMatching:(NSPredicate *)predicate keysToFetch:(NSArray *)keys unify:(BOOL)unify
                             mutable:(BOOL)mutableObjects sortOrder:(CNContactSortOrder)sortOrder error:(NSError **)error;
@end

@interface CharonContactsHistory : NSObject
+ (NSData *)currentToken;
+ (CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *)enumeratorForRequest:(CNChangeHistoryFetchRequest *)request error:(NSError **)error;
@end

@interface CNChangeHistoryAddContactEvent (Charon)
+ (instancetype)charon_eventWithContact:(CNContact *)contact containerIdentifier:(NSString *)containerIdentifier;
@end

@interface CNChangeHistoryUpdateContactEvent (Charon)
+ (instancetype)charon_eventWithContact:(CNContact *)contact;
@end

@interface CNChangeHistoryDeleteContactEvent (Charon)
+ (instancetype)charon_eventWithContactIdentifier:(NSString *)identifier;
@end

@interface CNChangeHistoryAddGroupEvent (Charon)
+ (instancetype)charon_eventWithGroup:(CNGroup *)group containerIdentifier:(NSString *)containerIdentifier;
@end

@interface CNChangeHistoryUpdateGroupEvent (Charon)
+ (instancetype)charon_eventWithGroup:(CNGroup *)group;
@end

@interface CNChangeHistoryDeleteGroupEvent (Charon)
+ (instancetype)charon_eventWithGroupIdentifier:(NSString *)identifier;
@end

@interface CNChangeHistoryAddMemberToGroupEvent (Charon)
+ (instancetype)charon_eventWithMember:(CNContact *)member group:(CNGroup *)group;
@end

@interface CNChangeHistoryRemoveMemberFromGroupEvent (Charon)
+ (instancetype)charon_eventWithMember:(CNContact *)member group:(CNGroup *)group;
@end

@interface CNPostalAddress (Charon)
- (NSString *)charon_fieldForKey:(NSString *)key;
- (void)charon_setField:(NSString *)value forKey:(NSString *)key;
- (NSDictionary *)charon_fields;
@end

@interface CNLabeledValue (Charon)
+ (instancetype)charon_labeledValueWithLabel:(NSString *)label value:(id)value identifier:(ABMultiValueIdentifier)identifier;
- (ABMultiValueIdentifier)charon_addressBookIdentifier;
@end
