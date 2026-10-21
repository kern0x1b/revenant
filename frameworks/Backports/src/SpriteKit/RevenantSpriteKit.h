#ifndef RevenantSpriteKit_h
#define RevenantSpriteKit_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <TargetConditionals.h>
#import <SpriteKit/SpriteKit.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@class SKTexture;
@class SKScene;
@class SKView;

#if TARGET_OS_IPHONE
@class UIColor;
typedef UIColor RevenantSKColor;
#else
@class NSColor;
typedef NSColor RevenantSKColor;
#endif

@interface SKNode (RevenantSpriteKitMatching)
- (NSArray *)revenant_nodesMatchingPath:(NSString *)path;
@end

@interface SKNode (RevenantSpriteKit8)
- (NSArray *)objectForKeyedSubscript:(NSString *)path;
@end

@interface SKNode (RevenantSpriteKit9)
- (void)moveToParent:(SKNode *)parent;
@end

@interface SKShapeNode (RevenantSpriteKitShape8)

+ (instancetype)shapeNodeWithPoints:(CGPoint *)points count:(size_t)numPoints;
+ (instancetype)shapeNodeWithSplinePoints:(CGPoint *)points count:(size_t)numPoints;

@property (nonatomic, retain) SKTexture *fillTexture;
@property (nonatomic, retain) SKTexture *strokeTexture;

@end

@class CIFilter;

@interface SKScene (RevenantSpriteKitView)
- (void)revenant_setView:(SKView *)view;
@end

@interface SKNode (RevenantSpriteKitScene)
@property (nonatomic, readonly) SKScene *scene;
@end

@protocol SKSceneDelegate;

@interface SKScene (RevenantSpriteKitScene8)
@property (nonatomic, weak) id<SKSceneDelegate> delegate;
- (void)didApplyConstraints;
- (void)didFinishUpdate;
@end

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#endif

#endif
