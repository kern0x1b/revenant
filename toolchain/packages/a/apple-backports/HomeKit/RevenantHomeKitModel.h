#ifndef REVENANT_HOMEKIT_MODEL_H
#define REVENANT_HOMEKIT_MODEL_H

#import <Foundation/Foundation.h>
#import <HomeKit/HomeKit.h>
#import "RevenantHomeKitStore.h"
#import "RevenantHomeKitConstants.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RevenantHomeKitHomeOrderKey;

NSMutableDictionary *RevenantHomeKitRecord(NSString *table, NSString *identifier);
id RevenantHomeKitField(NSMutableDictionary *record, NSString *key, id fallback);
NSString *RevenantHomeKitStringField(NSMutableDictionary *record, NSString *key, NSString *fallback);
BOOL RevenantHomeKitBoolField(NSMutableDictionary *record, NSString *key, BOOL fallback);
NSArray<NSString *> *RevenantHomeKitStringListField(NSMutableDictionary *record, NSString *key);
void RevenantHomeKitSetField(NSString *table, NSString *identifier, NSString *key, id _Nullable value);

void RevenantHomeKitOnMainQueue(void (^work)(void));

NSError *RevenantHomeKitError(HMErrorCode code, NSString *localizedDescription);
NSError *RevenantHomeKitErrorForAccessory(HMErrorCode code, HMAccessory * _Nullable accessory, NSString *localizedDescription);

void RevenantHomeKitTell(id _Nullable delegate, SEL selector, void (^work)(id target));

void RevenantHomeKitFinish(void (^ _Nullable handler)(id _Nullable, NSError * _Nullable), id _Nullable result, NSError * _Nullable error);
void RevenantHomeKitFinishError(void (^ _Nullable handler)(NSError * _Nullable), NSError * _Nullable error);

NS_ASSUME_NONNULL_END

#endif
