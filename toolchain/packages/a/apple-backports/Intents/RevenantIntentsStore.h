#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

extern NSString *charon_intents_store_directory(void);

extern NSArray *charon_intents_stored_interactions(NSString *groupIdentifier);

extern NSError *charon_intents_store_interaction(INInteraction *interaction);

extern NSError *charon_intents_delete_interactions(NSArray *identifiers, NSString *groupIdentifier);

extern NSOrderedSet *charon_intents_vocabulary(NSInteger type);

extern void charon_intents_store_vocabulary(NSInteger type, NSArray *phrases);

extern void charon_intents_remove_vocabulary(void);
