#ifndef REVENANT_CA_SPRING_ANIMATION_H
#define REVENANT_CA_SPRING_ANIMATION_H

#import <QuartzCore/QuartzCore.h>

#ifdef REVENANT_HOST_BUILD
@interface RevenantCASpringAnimation : CABasicAnimation

@property CGFloat mass;
@property CGFloat stiffness;
@property CGFloat damping;
@property CGFloat initialVelocity;
@property BOOL allowsOverdamping;
@property (nonatomic, readonly) CFTimeInterval settlingDuration;
@property (nonatomic, readonly) CFTimeInterval perceptualDuration;
@property (nonatomic, readonly) CGFloat bounce;

- (instancetype)initWithKeyPath:(NSString *)keyPath;
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce;

@end
#else
@compatibility_alias RevenantCASpringAnimation CASpringAnimation;
@interface CASpringAnimation (Revenant)
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce;
- (CFTimeInterval)settlingDuration;
- (CFTimeInterval)perceptualDuration;
- (CGFloat)bounce;
@end
#endif

#endif
