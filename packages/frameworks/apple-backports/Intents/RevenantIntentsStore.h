#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

extern NSString *revenant_intents_store_directory(void);

extern NSArray *revenant_intents_stored_interactions(NSString *groupIdentifier);

extern NSError *revenant_intents_store_interaction(INInteraction *interaction);

extern NSError *revenant_intents_delete_interactions(NSArray *identifiers, NSString *groupIdentifier);

extern NSOrderedSet *revenant_intents_vocabulary(NSInteger type);

extern void revenant_intents_store_vocabulary(NSInteger type, NSArray *phrases);

extern void revenant_intents_remove_vocabulary(void);
