#import "CharonSCN.h"

NSString *const SCNSceneStartTimeAttributeKey = @"SCNSceneStartTimeAttributeKey";
NSString *const SCNSceneEndTimeAttributeKey = @"SCNSceneEndTimeAttributeKey";
NSString *const SCNSceneFrameRateAttributeKey = @"SCNSceneFrameRateAttributeKey";
NSString *const SCNSceneUpAxisAttributeKey = @"SCNSceneUpAxisAttributeKey";

@implementation SCNScene
{
    NSMutableDictionary<NSString *, id> *_attributes;
    NSURL *_sourceURL;
    SCNMaterialProperty *_background;
    SCNMaterialProperty *_lightingEnvironment;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _rootNode = [SCNNode node];
        _attributes = [NSMutableDictionary dictionary];
        _physicsWorld = [[SCNPhysicsWorld alloc] init];
        // made with their scene, as a material's slots are: they sample the nearest mipmap level (mipFilter 1 on macOS,
        // tests/backports/device/scenekit-defaults-expectations.h), a property made alone does not
        _background = [SCNMaterialProperty new];
        _background.mipFilter = SCNFilterModeNearest;
        _lightingEnvironment = [SCNMaterialProperty new];
        _lightingEnvironment.mipFilter = SCNFilterModeNearest;
    }
    return self;
}

+ (instancetype)scene
{
    return [[self alloc] init];
}

@synthesize rootNode = _rootNode;
@synthesize physicsWorld = _physicsWorld;

- (SCNMaterialProperty *)background
{
    return _background;
}

- (SCNMaterialProperty *)lightingEnvironment
{
    return _lightingEnvironment;
}

- (NSURL *)charonSourceURL
{
    return _sourceURL;
}

- (id)attributeForKey:(NSString *)key
{
    return _attributes[key];
}

- (void)setAttribute:(id)attribute forKey:(NSString *)key
{
    if (attribute) {
        _attributes[key] = attribute;
    } else {
        [_attributes removeObjectForKey:key];
    }
}

+ (instancetype)sceneWithURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (data == nil) {
        return nil;
    }
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = YES;
    id root = nil;
    [CharonSCNCoding pushSourceURL:url];
    @try {
        root = [unarchiver decodeObjectOfClass:[SCNScene class] forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:SCNErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"the archive names a class this port does not carry"}];
        }
        [CharonSCNCoding popSourceURL];
        return nil;
    }
    [CharonSCNCoding popSourceURL];
    [unarchiver finishDecoding];
    if (![root isKindOfClass:[SCNScene class]]) {
        if (error) {
            *error = [NSError errorWithDomain:SCNErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"the archive's top level object is not a SCNScene"}];
        }
        return nil;
    }
    ((SCNScene *)root)->_sourceURL = url;
    return root;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        SCNNode *root = [coder decodeObjectOfClass:[SCNNode class] forKey:@"rootNode"];
        if (root) {
            _rootNode = root;
        }
        SCNPhysicsWorld *physicsWorld = [coder decodeObjectOfClass:[SCNPhysicsWorld class] forKey:@"physicsWorld"];
        if (physicsWorld) {
            _physicsWorld = physicsWorld;
        }
        // the archive keys are background and environment (star2.scn)
        SCNMaterialProperty *background = [coder decodeObjectOfClass:[SCNMaterialProperty class] forKey:@"background"];
        if (background) {
            _background = background;
        }
        SCNMaterialProperty *environment = [coder decodeObjectOfClass:[SCNMaterialProperty class] forKey:@"environment"];
        if (environment) {
            _lightingEnvironment = environment;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_rootNode forKey:@"rootNode"];
    [coder encodeObject:_physicsWorld forKey:@"physicsWorld"];
    [coder encodeObject:_background forKey:@"background"];
    [coder encodeObject:_lightingEnvironment forKey:@"environment"];
}

@end
