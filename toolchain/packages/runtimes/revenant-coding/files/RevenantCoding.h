#import <Foundation/Foundation.h>

extern NSSet *revenant_intents_allowed_classes(void);

extern void revenant_intents_encode(id object, NSCoder *coder);

extern void revenant_intents_decode(id object, NSCoder *coder);

extern void revenant_intents_copy(id copy, id object);

extern int revenant_copy_is_copy_for_testing(Class owner, const char *ivar);

extern id revenant_intents_super_init(id object, Class superclass);
