#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>

// The four geometry file types ModelIO's own header declares, which arrived with iOS 9. They are
// exported data symbols of ModelIO.framework, and the release exports none of them, so an
// application that names one is killed by dyld before its main; the values are the ones the host's
// own ModelIO holds, read off the symbol there (facts/ModelIO/UTTypes.md).

NSString *const kUTType3dObject = @"public.geometry-definition-format";
NSString *const kUTTypeAlembic = @"public.alembic";
NSString *const kUTTypePolygon = @"public.polygon-file-format";
NSString *const kUTTypeStereolithography = @"public.standard-tesselated-geometry-format";
