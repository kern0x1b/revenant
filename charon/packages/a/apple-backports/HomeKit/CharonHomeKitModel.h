// What the HomeKit model files share: how a record is read out of the store and written back, how a
// delegate message is delivered the way HomeKit delivers it, and how an error of HMErrorDomain is
// made. Every declaration here is the port's own name, so nothing in this header is API.
//
// **Where the model lives.** iOS 6 runs no home hub, no homekitd and no accessories daemon, so there
// is no system service to ask for a home graph. The port keeps the graph itself, in
// CharonHomeKitStore, and the objects the application sees are windows onto it: a name changed
// through HMHome is in the store before -updateName:completionHandler: calls back, and a graph
// written by one launch is there for the next. That is what makes the store real rather than a
// cache of what the process happens to be holding.
//
// **Where an accessory's own values come from.** A characteristic's value and whether an accessory is
// reachable are the accessory's own, and the port has no HAP transport and no session with any
// accessory: the HAP code that is in the tree is CharonHapCrypto.h (the curves and the AEAD HAP pairs
// with) and CharonHAPBignum.h (the arithmetic under it), and neither of them opens a session. So
// these answer HMErrorCodeAccessoryNotReachable, and the graph itself -- names, rooms, the services and
// characteristics an accessory advertises, the action sets and the triggers -- is answered from the
// store, and answered the same way on every launch.
#ifndef CHARON_HOMEKIT_MODEL_H
#define CHARON_HOMEKIT_MODEL_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>
#import "CharonHomeKitStore.h"
#import "CharonHomeKitConstants.h"

NS_ASSUME_NONNULL_BEGIN

// The key the manager's own ordering of the homes is held under, in the same table the home records
// are in: a home is a row of that table like any other object, and the order is one more row, so a
// store that grew a home and a store that grew its order cannot disagree about it.
extern NSString *const CharonHomeKitHomeOrderKey;

// The record of one object, as the store holds it: a mutable dictionary the object reads its own
// fields from and writes them back to. A record is created on first use, so an object an application
// made with -init and never added to a home is still describable.
NSMutableDictionary *CharonHomeKitRecord(NSString *table, NSString *identifier);
// Reads one field, writing the record's default in when the field is not there yet.
id CharonHomeKitField(NSMutableDictionary *record, NSString *key, id fallback);
// The same, for a field that holds a number, and for one that holds a list of strings.
NSString *CharonHomeKitStringField(NSMutableDictionary *record, NSString *key, NSString *fallback);
BOOL CharonHomeKitBoolField(NSMutableDictionary *record, NSString *key, BOOL fallback);
NSArray<NSString *> *CharonHomeKitStringListField(NSMutableDictionary *record, NSString *key);
// Writes a field and flushes the table. A nil value removes the key, which is how a field is unset.
void CharonHomeKitSetField(NSString *table, NSString *identifier, NSString *key, id _Nullable value);

// The store's main queue for delegate messages. HomeKit delivers every completion handler and every
// delegate message on the main queue, whatever thread the call was made from, and a handler that is
// called on the queue it is documented on is a handler an application can rely on; this is that
// queue, in one place so it cannot drift.
void CharonHomeKitOnMainQueue(void (^work)(void));

// An error of HMErrorDomain with the given HMErrorCode and, when there is one, the accessory the
// failure is about -- which is what HomeKit puts in the userInfo, and what an application reads to
// tell two failures apart.
NSError *CharonHomeKitError(HMErrorCode code, NSString *localizedDescription);
NSError *CharonHomeKitErrorForAccessory(HMErrorCode code, HMAccessory * _Nullable accessory, NSString *localizedDescription);

// Calls a delegate method when the delegate is there and answers the selector, the way every
// framework's own dispatch does. `work` receives the delegate, so the caller sends the message
// itself and the shape of the message is at the call site, where it can be read.
void CharonHomeKitTell(id _Nullable delegate, SEL selector, void (^work)(id target));

// A completion handler called on the main queue with a result and an error, once, whatever the
// thread the work finished on. HAP calls back with (value, nil) on success and (nil, error) on
// failure, never both and never neither.
void CharonHomeKitFinish(void (^ _Nullable handler)(id _Nullable, NSError * _Nullable), id _Nullable result, NSError * _Nullable error);
// The shape HomeKit uses for a method whose handler takes only the error, which is most of them.
void CharonHomeKitFinishError(void (^ _Nullable handler)(NSError * _Nullable), NSError * _Nullable error);

NS_ASSUME_NONNULL_END

#endif
