#import <UIKit/UIKit.h>

@implementation NSAttributedString (RevenantFileURL7)

- (instancetype)initWithFileURL:(NSURL *)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)options documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> * _Nullable *)dict error:(NSError * _Nullable *)error
{
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data)
        return nil;
    return [self initWithData:data options:options documentAttributes:dict error:error];
}

@end

@implementation NSMutableAttributedString (RevenantFileURL7)

- (BOOL)readFromFileURL:(NSURL *)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *)opts documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> * _Nullable *)dict error:(NSError * _Nullable *)error
{
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    return data && [self readFromData:data options:opts documentAttributes:dict error:error];
}

@end
