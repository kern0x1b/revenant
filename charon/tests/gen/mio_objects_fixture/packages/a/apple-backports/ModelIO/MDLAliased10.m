#import <ModelIO/ModelIO.h>

// Defined through CHARON_ALIAS: the file declares the class (its symbol is the release's own name) and a category of it in the same
// file. The class is owned by this folder, so a band object does not declare it again; the member the category implements is
// defined by the folder too.
CHARON_ALIAS(MDLAliased)

@implementation CHARON_ALIAS_CLASS(MDLAliased) (CharonAlias)
- (id)aliasedThing:(id)a {
    return nil;
}
@end
