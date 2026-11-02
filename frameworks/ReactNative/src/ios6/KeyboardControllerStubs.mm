#import <UIKit/UIKit.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTViewComponentView.h>
#import <ReactCommon/RCTTurboModule.h>
#import <react/renderer/components/RNKC/RNKCClippingScrollViewDecoratorViewComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCKeyboardBackgroundViewComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCKeyboardControllerViewComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCKeyboardExtenderComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCKeyboardGestureAreaComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCKeyboardToolbarGroupViewComponentDescriptor.h>
#import <react/renderer/components/RNKC/RNKCOverKeyboardViewComponentDescriptor.h>
#import "RNKC/RNKC.h"

using namespace facebook::react;

@interface KeyboardController : NSObject <RCTBridgeModule, NativeKeyboardControllerSpec>
@end

@implementation KeyboardController

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSDictionary *)constantsToExport
{
  return @{@"keyboardBorderRadius" : @0};
}

- (NSDictionary *)getConstants
{
  return [self constantsToExport];
}

- (void)setInputMode:(double)mode {}
- (void)setDefaultMode {}
- (void)preload {}
- (void)dismiss:(BOOL)keepFocus animated:(BOOL)animated {}
- (void)setFocusTo:(NSString *)direction {}
- (void)viewPositionInWindow:(double)viewTag resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@{@"x" : @0, @"y" : @0, @"width" : @0, @"height" : @0});
}
- (void)addListener:(NSString *)eventName {}
- (void)removeListeners:(double)count {}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeKeyboardControllerSpecJSI>(params);
}

@end

#define RNHOST_KEYBOARD_VIEW(NAME)                                               \
  @interface NAME : RCTViewComponentView                                         \
  @end                                                                           \
  @implementation NAME                                                           \
  + (ComponentDescriptorProvider)componentDescriptorProvider                     \
  {                                                                              \
    return concreteComponentDescriptorProvider<NAME##ComponentDescriptor>();     \
  }                                                                              \
  @end

RNHOST_KEYBOARD_VIEW(KeyboardControllerView)
RNHOST_KEYBOARD_VIEW(KeyboardGestureArea)
RNHOST_KEYBOARD_VIEW(OverKeyboardView)
RNHOST_KEYBOARD_VIEW(KeyboardBackgroundView)
RNHOST_KEYBOARD_VIEW(KeyboardExtender)
RNHOST_KEYBOARD_VIEW(ClippingScrollViewDecoratorView)
RNHOST_KEYBOARD_VIEW(KeyboardToolbarGroupView)
