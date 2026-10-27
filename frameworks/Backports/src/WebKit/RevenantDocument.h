#import <Foundation/Foundation.h>

@protocol RevenantDocumentSource <NSObject>
- (NSArray<NSString *> *)revenant_documentStartScripts;
- (void)revenant_documentDidInject;
- (void)revenant_decideResponse:(NSURLResponse *)response completion:(void (^)(NSInteger policy))completion;
- (void)revenant_downloadResponse:(NSURLResponse *)response request:(NSURLRequest *)request;
@end

NSString *RevenantDocumentRegister(id<RevenantDocumentSource> source);
void RevenantDocumentTagRequest(NSMutableURLRequest *request, NSString *token);
NSURLRequest *RevenantDocumentTaggedCopy(NSURLRequest *request, NSString *token);
NSURLRequest *RevenantDocumentInnerCopy(NSURLRequest *request);
BOOL RevenantDocumentIsTagged(NSURLRequest *request);
BOOL RevenantDocumentIsWebURL(NSURL *URL);
void RevenantDocumentExpect(NSString *token, NSURL *URL);
void RevenantDocumentForget(NSString *token);
NSString *RevenantDocumentStartedScript(NSString *token);

NSData *RevenantDocumentRewrite(NSData *body, NSString *contentEncoding, NSString *charset, NSArray<NSString *> *scripts);
NSString *RevenantDocumentInsert(NSString *html, NSArray<NSString *> *scripts);
NSString *RevenantDocumentCSPWithHashes(NSString *policy, NSArray<NSString *> *scripts);
NSString *RevenantDocumentHash(NSString *script);
