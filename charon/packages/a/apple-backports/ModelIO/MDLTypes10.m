#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>

// The universal scene description type, declared at MDLTypes.h:29 of the 16.4 SDK with
// API_AVAILABLE(ios(10.0)). Its own object, because an object carries the API of one release and
// this name first appears in a later one than the four in MDLTypes9.m.

NSString *const kUTTypeUniversalSceneDescription = @"com.pixar.universal-scene-description";
