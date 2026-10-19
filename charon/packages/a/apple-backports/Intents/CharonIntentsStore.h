// The two stores an application on this release can really keep.
//
// The interaction store is what stands in for the assistant daemon a donation is meant for: an
// interaction the application donates is archived into this application's own Application
// Support, and read back through the two accessors CharonIntents100.m declares on INInteraction.
// The vocabulary store is the same for the phrases an application offers: they are written where
// the setter that offered them put them and read back through the accessor on INVocabulary.
//
// Neither of these is a cache of Apple's own service and neither pretends to be: the files are
// this package's, under the port's own name, and an application that wants Apple's behaviour on
// a release that has it gets Intents.framework instead (see modules/apple/backports.lua's band).
//
// Every name here is Charon's own and every one is hidden at the link (a name starting with
// charon_ is what modules/apple/backports.lua's internal_symbol() calls internal), so this file
// carries no API symbol and the release check has nothing to place in it.

#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

// The directory the two stores are written in, under this application's own Application Support,
// created on first use.
extern NSString *charon_intents_store_directory(void);

// The interactions this application has donated, newest last, optionally only those of one group.
extern NSArray *charon_intents_stored_interactions(NSString *groupIdentifier);

// Archives the interaction and returns nil, or the error the write failed with.
extern NSError *charon_intents_store_interaction(INInteraction *interaction);

// Removes the interactions the two arguments name: by identifier, by group identifier, or all of
// them when both are nil. Returns nil, or the error the write failed with.
extern NSError *charon_intents_delete_interactions(NSArray *identifiers, NSString *groupIdentifier);

// The phrases this application offered for one vocabulary type, in the order it offered them.
// The type is taken as the integer it is (NS_ENUM(NSInteger, INVocabularyStringType)), so this
// header's C interface does not depend on the framework's own headers for it.
extern NSOrderedSet *charon_intents_vocabulary(NSInteger type);

extern void charon_intents_store_vocabulary(NSInteger type, NSArray *phrases);

extern void charon_intents_remove_vocabulary(void);
