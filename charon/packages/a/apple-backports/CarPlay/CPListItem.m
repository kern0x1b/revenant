// CPListItem, over the name the release already carries for a class of its own.
//
// Measured, and this is the whole of the finding: the armv7 dyld shared cache of 6.1.3 exports a
// class called CPListItem, and it is NOT CarPlay's. apple.objc.inventory over that cache shows its
// own eleven methods and they are -addParagraph:, -paragraphAtIndex:, -paragraphCount, -list, -number,
// -setList: and -setNumber: -- some framework's private list item, with no text, no detailText, no
// image, no accessoryType and no handler. Apple's CarPlay CPListItem is iOS 12 and is not in this
// release at all; its name is taken.
//
// So the name is an ALIAS: CHARON_ALIAS defines CharonCPListItem, exports the release's name to it,
// and records the pair in __DATA,__charon_alias, which the library's loader (attach.c) acts on. A
// subclass an application writes of CPListItem then inherits the release's class and is laid out
// after it; sent to CharonCPListItem itself, the class introspection answers as the release's class
// does, so [CPListItem class], what [CPListItem alloc] makes and what the release hands out are one
// class. That is how the port has always handled a name a release carries and Apple did not
// (UIKit's NSTextList and NSTextTab are the same case, and their rows in registry/UIKit/base.json say
// so).
//
// The class itself is the one in CarPlayTemplatesView12.m: a row, conforming to CPSelectableListItem,
// with the header's own three initialisers and its own handler. This file is only the alias, and it
// is its own object because the alias is a class of Charon's own and mixes no release with it.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "../charon_alias.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

CHARON_ALIAS(CPListItem)
