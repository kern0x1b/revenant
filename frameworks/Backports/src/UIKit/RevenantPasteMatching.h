#import <Foundation/Foundation.h>

static inline BOOL revenant_paste_accepts(NSArray<NSItemProvider *> *itemProviders, NSArray<NSString *> *typeIdentifiers)
{
    for (NSItemProvider *provider in itemProviders) {
        for (NSString *typeIdentifier in typeIdentifiers) {
            if ([provider hasItemConformingToTypeIdentifier:typeIdentifier])
                return YES;
        }
    }
    return NO;
}
