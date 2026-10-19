#import <Foundation/Foundation.h>

extern NSSet *charon_intents_allowed_classes(void);

extern void charon_intents_encode(id object, NSCoder *coder);

extern void charon_intents_decode(id object, NSCoder *coder);

extern void charon_intents_copy(id copy, id object);

extern int charon_copy_is_copy_for_testing(Class owner, const char *ivar);

extern id charon_intents_super_init(id object, Class superclass);
