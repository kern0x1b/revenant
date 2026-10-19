#ifndef CHARON_HOMEKIT_MODEL_H
#define CHARON_HOMEKIT_MODEL_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>
#import "CharonHomeKitStore.h"
#import "CharonHomeKitConstants.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CharonHomeKitHomeOrderKey;

NSMutableDictionary *CharonHomeKitRecord(NSString *table, NSString *identifier);
id CharonHomeKitField(NSMutableDictionary *record, NSString *key, id fallback);
NSString *CharonHomeKitStringField(NSMutableDictionary *record, NSString *key, NSString *fallback);
BOOL CharonHomeKitBoolField(NSMutableDictionary *record, NSString *key, BOOL fallback);
NSArray<NSString *> *CharonHomeKitStringListField(NSMutableDictionary *record, NSString *key);
void CharonHomeKitSetField(NSString *table, NSString *identifier, NSString *key, id _Nullable value);

void CharonHomeKitOnMainQueue(void (^work)(void));

NSError *CharonHomeKitError(HMErrorCode code, NSString *localizedDescription);
NSError *CharonHomeKitErrorForAccessory(HMErrorCode code, HMAccessory * _Nullable accessory, NSString *localizedDescription);

void CharonHomeKitTell(id _Nullable delegate, SEL selector, void (^work)(id target));

void CharonHomeKitFinish(void (^ _Nullable handler)(id _Nullable, NSError * _Nullable), id _Nullable result, NSError * _Nullable error);
void CharonHomeKitFinishError(void (^ _Nullable handler)(NSError * _Nullable), NSError * _Nullable error);

NS_ASSUME_NONNULL_END

#endif
