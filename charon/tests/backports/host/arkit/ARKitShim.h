#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ARHitTestResultType) {
    ARHitTestResultTypeExistingPlaneUsingGeometry = 1 << 0,
    ARHitTestResultTypeEstimatedPlane = 1 << 1,
};

typedef NS_ENUM(NSInteger, ARRaycastTarget) { ARRaycastTargetAny = 0, ARRaycastTargetExistingPlaneGeometry = 2 };
typedef NS_ENUM(NSInteger, ARRaycastTargetAlignment) { ARRaycastTargetAlignmentAny = 0 };
typedef NS_ENUM(NSInteger, UIInterfaceOrientation) {
    UIInterfaceOrientationPortrait = 1,
    UIInterfaceOrientationLandscapeLeft = 4,
};

@protocol MTLDevice
@end

@class ARAnchor;
@class ARFrame;
@class ARSession;
@class ARHitTestResult;
@class ARRaycastQuery;
@class ARRaycastResult;
@class ARSCNViewDelegate;
@class ARPlaneGeometry;
@class ARGeometryElement;

@interface ARAnchor : NSObject
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, assign) simd_float4x4 transform;
@end

@class ARCamera;
@interface ARFrame : NSObject
@property (nonatomic, readonly, nullable) ARCamera *camera;
@property (nonatomic, readonly, nullable) ARHitTestResult *hitTestResult;
- (NSArray<ARHitTestResult *> *)hitTest:(CGPoint)point types:(ARHitTestResultType)types;
- (nullable ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point
                                    allowingTarget:(ARRaycastTarget)target
                                          alignment:(ARRaycastTargetAlignment)alignment;
@end

@interface ARCamera : NSObject
@property (nonatomic, assign) simd_float4x4 transform;
@property (nonatomic, assign) simd_float3x3 intrinsics;
@property (nonatomic, assign) CGSize imageResolution;
- (CGPoint)projectPoint:(simd_float3)point
            orientation:(UIInterfaceOrientation)orientation
            viewportSize:(CGSize)viewportSize;
- (simd_float3)unprojectPoint:(CGPoint)point
         ontoPlaneWithTransform:(simd_float4x4)planeTransform
                  orientation:(UIInterfaceOrientation)orientation
                  viewportSize:(CGSize)viewportSize;
@end

@interface ARSession : NSObject
@property (nonatomic, readonly, nullable) ARFrame *currentFrame;
@end

@interface ARHitTestResult : NSObject
@end
@interface ARRaycastQuery : NSObject
@end
@interface ARRaycastResult : NSObject
@end
@interface ARPlaneGeometry : NSObject
@property (nonatomic, readonly) NSUInteger vertexCount;
@property (nonatomic, readonly) NSUInteger textureCoordinateCount;
@property (nonatomic, readonly) NSUInteger triangleCount;
@property (nonatomic, readonly) NSUInteger boundaryVertexCount;
@property (nonatomic, readonly) const simd_float3 *vertices;
@property (nonatomic, readonly) const simd_float2 *textureCoordinates;
@property (nonatomic, readonly) const int16_t *triangleIndices;
@property (nonatomic, readonly) const simd_float3 *boundaryVertices;
@end

@protocol ARSCNViewDelegate <NSObject>
@optional
- (nullable SCNNode *)renderer:(id)renderer nodeForAnchor:(ARAnchor *)anchor;
- (void)renderer:(id)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
- (void)renderer:(id)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor;
@end

@interface ARSCNView : SCNView
@property (nonatomic, strong, nullable) ARSession *session;
@property (nonatomic, weak, nullable) id<ARSCNViewDelegate> delegate;
@property (nonatomic, assign) BOOL automaticallyUpdatesLighting;
@property (nonatomic, assign) BOOL rendersCameraGrain;
@property (nonatomic, assign) BOOL rendersMotionBlur;

@property (nonatomic, strong, readonly) NSMapTable<SCNNode *, ARAnchor *> *anchorsByNode;
@property (nonatomic, strong, readonly) NSMapTable<ARAnchor *, SCNNode *> *nodesByAnchor;

- (void)charon_placeAnchor:(ARAnchor *)anchor atNode:(SCNNode *)node;
- (void)charon_moveAnchor:(ARAnchor *)anchor toNode:(SCNNode *)node;
- (void)charon_removeAnchor:(ARAnchor *)anchor;
- (nullable ARAnchor *)anchorForNode:(SCNNode *)node;
- (nullable SCNNode *)nodeForAnchor:(ARAnchor *)anchor;
- (NSArray<ARHitTestResult *> *)hitTest:(CGPoint)point types:(ARHitTestResultType)types;
- (nullable ARRaycastQuery *)raycastQueryFromPoint:(CGPoint)point
                                    allowingTarget:(ARRaycastTarget)target
                                          alignment:(ARRaycastTargetAlignment)alignment;
@end

@interface ARSCNView (Charon12)
- (simd_float3)unprojectPoint:(CGPoint)point
         ontoPlaneWithTransform:(simd_float4x4)planeTransform;
@end

@interface SCNGeometry (CharonReplace)
- (void)charon_replaceSources:(NSArray<SCNGeometrySource *> *)sources
                     elements:(NSArray<SCNGeometryElement *> *)elements;
@end

@interface ARReferenceImage : NSObject
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly) CGSize physicalSize;
@property (nonatomic, strong, readonly, nullable) NSString *resourceGroupName;
- (instancetype)initWithCGImage:(CGImageRef)image
                     orientation:(CGImagePropertyOrientation)orientation
                  physicalWidth:(CGFloat)physicalWidth;
- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                         orientation:(CGImagePropertyOrientation)orientation
                      physicalWidth:(CGFloat)physicalWidth;
+ (nullable NSSet<ARReferenceImage *> *)referenceImagesInGroupNamed:(NSString *)name
                                                            bundle:(nullable NSBundle *)bundle;
- (void)validateWithCompletionHandler:(void (^)(NSError *_Nullable error))completionHandler;
@end

@interface ARSCNPlaneGeometry : SCNGeometry
+ (nullable instancetype)planeGeometryWithDevice:(id<MTLDevice>)device;
- (void)updateFromPlaneGeometry:(ARPlaneGeometry *)planeGeometry;
@end

NS_ASSUME_NONNULL_END
