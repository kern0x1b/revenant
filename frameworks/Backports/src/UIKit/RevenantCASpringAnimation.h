#ifndef REVENANT_CA_SPRING_ANIMATION_H
#define REVENANT_CA_SPRING_ANIMATION_H

#import <QuartzCore/QuartzCore.h>

@interface RevenantCASpringAnimation : CABasicAnimation

@property CGFloat mass;
@property CGFloat stiffness;
@property CGFloat damping;
@property CGFloat initialVelocity;
@property BOOL allowsOverdamping;
@property (nonatomic, readonly) CFTimeInterval settlingDuration;
@property (nonatomic, readonly) CFTimeInterval perceptualDuration;
@property (nonatomic, readonly) CGFloat bounce;

- (instancetype)initWithPerceptualDuration:(CFTimeInterval)perceptualDuration bounce:(CGFloat)bounce;

@end

#endif
