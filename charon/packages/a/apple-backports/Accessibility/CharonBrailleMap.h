//
//  CharonBrailleMap.h
//  Accessibility
//
//  The one way a caller can make a braille map, and nothing else.
//
//  The header of 26.2 marks AXBrailleMap's -init and +new unavailable and gives no other way to make
//  one, so on a real device nothing but the braille display service ever holds a map, and no release
//  this port carries has such a service. A caller that wants a map has to be able to ask for one, so
//  the port adds one way to ask - Charon's own spelling, the arrangement
//  CharonAccessibility.h uses for AXRequest's own methods for the same reason - and the SDK's own
//  initialisers stay exactly where they are.
//
//  It is its own header and not a line in CharonAccessibility.h, because that file transcribes
//  AXBrailleTable, AXBrailleTranslationResult and AXBrailleTranslator: a program that imported it and
//  the SDK's own umbrella would have two declarations of three classes, and clang says so by name.
//
//  The class itself is declared by the SDK the package compiles against, so this is a category and not
//  a second declaration of the class, for the reason CharonAccessibilityProtocols.h gives.
//

#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <CoreGraphics/CoreGraphics.h>

@interface AXBrailleMap (CharonFactory)

// A map of the given size, with every pin lowered. The size is the one asked for and not one the port
// decides: the system's map is sized by the display service and the user can zoom it afterwards, and
// this is the only place a port caller can say what it wants.
+ (instancetype)charon_mapWithDimensions:(CGSize)dimensions;

@end
