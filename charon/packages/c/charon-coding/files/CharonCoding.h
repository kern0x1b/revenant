// The secure coding and the copying the Intents data classes share.
//
// One definition, reached from every generated object file in this package, so a class's
// archive is one function's idea of what to walk rather than a per-class list that can drift
// from the class: the walker reads the class's own ivar list through the Objective-C runtime,
// from the object's class up to NSObject, so a subclass carries its parent's state without
// either of them naming it, and a property added to a class later is carried by the same code.
//
// It is a class of Charon's own in nothing: no API symbol here is exported (every name starts
// with charon_, which modules/apple/backports.lua's internal_symbol() hides at the link), so
// this file carries nothing the registry has to place and every band keeps it.

#import <Foundation/Foundation.h>

// Every class an Intents archive may hold in one of its keys, so decodeObjectOfClasses: has a
// set to answer with. NSArray, NSDictionary, NSSet and NSString themselves are in it because
// Foundation's own archives nest them.
extern NSSet *charon_intents_allowed_classes(void);

// Writes every ivar of the object, and of every class above it, under a key that names the
// class that owns the ivar: an object pointer by its value, and a value type by its bytes.
extern void charon_intents_encode(id object, NSCoder *coder);

// Reads back what charon_intents_encode wrote, from the same keys, and answers nil for an
// object of a class that is not in the allowed set, which is what NSSecureCoding requires.
extern void charon_intents_decode(id object, NSCoder *coder);

// Copies every ivar of the object, and of every class above it, into the copy: an object
// pointer by copy, and a value type by its bytes.
extern void charon_intents_copy(id copy, id object);

// What the copy decides for one ivar of a class, as 1 for copy and 0 for share. Exposed for the
// test that checks the decision, which is tests/backports/callgen/ownership-test.m.
extern int charon_copy_is_copy_for_testing(Class owner, const char *ivar);

// The superclass's own -init, made explicitly. A class whose header marks its own -init
// unavailable - which most Intents classes do - cannot spell [super init] in a file that reads
// that header, and the superclass's -init is the only initialiser an archive of such a class
// can start from. objc_msgSendSuper is that call written out; the superclass is passed in
// because it is the one the header names.
extern id charon_intents_super_init(id object, Class superclass);
