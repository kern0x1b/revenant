#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

// AVMetadataItemValueRequest, iOS 9.
//
// A value request is what a metadata loader hands back to ask for one item's value, and what the
// caller answers with a value or an error. The 9.0 shape names the thing being asked for with a
// specifier and loads asynchronously; the current shape keeps -respondWithValue: and
// -respondWithError: and has dropped the specifier. The corpus row is the class and the corpus is the
// 26.2 surface, so the port carries the class and the members of BOTH generations over one request:
// the 7.0/9.0 spelling for an application written then, the current one for one written now, and the
// header's own -metadataItem on both.
//
// **Where the answer lives.** The handler the header declares takes no argument, and the header says
// in as many words that the caller answers by sending -respondWithValue: or -respondWithError: to this
// request. So the answer is state on the request, kept here and readable through the two charon_
// accessors below, and not something the block could have returned. A loader to read that answer is
// not carried yet - the metadata adaptor is a separate row - which is why the accessors are the port's
// own: without them the two respond methods would be writes that nothing could ever see, which is the
// silent shape this row must not be.

@interface AVMetadataItemValueRequest ()
@property (nonatomic, strong) id charonSpecifier;
@property (nonatomic, weak) AVMetadataItem *charonMetadataItem;
@property (nonatomic, strong) id charonResponseValue;
@property (nonatomic, strong) NSError *charonResponseError;
@end

@implementation AVMetadataItemValueRequest

@synthesize charonSpecifier = _charonSpecifier;
@synthesize charonMetadataItem = _charonMetadataItem;
@synthesize charonResponseValue = _charonResponseValue;
@synthesize charonResponseError = _charonResponseError;

- (instancetype)charon_initWithSpecifier:(id)specifier
{
    self = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("init"));
    if (self) {
        _charonSpecifier = specifier;
    }
    return self;
}

- (id)specifier
{
    return self.charonSpecifier;
}

- (AVMetadataItem *)metadataItem
{
    return self.charonMetadataItem;
}

- (void)setMetadataItem:(AVMetadataItem *)metadataItem
{
    self.charonMetadataItem = metadataItem;
}

// The current shape, and the one the SDK the port compiles against declares: the handler takes no
// argument. The header says what happens next in as many words - the handler is the caller asking for
// the values, and the CALLER answers by sending -respondWithValue: or -respondWithError: to this
// request. So the handler being called is the request being served, and the answer comes back through
// the two methods below, not through the block.
- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys
                      completionHandler:(nullable void (^)(void))handler
{
    if (handler) {
        handler();
    }
}

// The answer, kept on the request so that a loader waiting on the other side of an exchange can read
// what the caller said. The header's own protocol for the value is NSCopying, and the value is copied
// so that a caller mutating what it passed cannot change what the request answers.
- (void)respondWithValue:(id<NSCopying>)value
{
    // -copy through the protocol the header declares for the value, so a caller that passes a
    // mutable object has its answer copied rather than aliased. Sent through id<NSCopying> because
    // the concrete type is the caller's, and a plain [value copy] does not type-check there.
    // -copy through the protocol the header declares for the value, sent through objc_msgSend because
    // the compiler will not resolve -copy on a protocol-typed id here (the SDK's NSCopying is declared
    // without the method in this configuration), and a plain [value copy] does not type-check on the
    // concrete type either. A caller that passes a mutable object has its answer copied, not aliased.
    self.charonResponseValue = value ? ((id (*)(id, SEL))objc_msgSend)(value, @selector(copy)) : nil;
    self.charonResponseError = nil;
}

- (void)respondWithError:(NSError *)error
{
    self.charonResponseError = error;
    self.charonResponseValue = nil;
}

// What the request was answered with, for this port's own code and its own tests. A loader is not
// carried yet - the metadata adaptor is a separate row - so there is no other reader of the answer, and
// without these the two methods above would be writes nothing could ever see.
- (id)charon_responseValue
{
    return self.charonResponseValue;
}

- (NSError *)charon_responseError
{
    return self.charonResponseError;
}

@end
