#ifndef REVENANT_SPRING_KEYFRAMES_H
#define REVENANT_SPRING_KEYFRAMES_H

#import <QuartzCore/QuartzCore.h>

typedef double (*RevenantSpringProgress)(double time, void *context);

id revenant_spring_interpolate(id from, id to, double progress);
id revenant_spring_offset(id value, id delta, double scale);
CAKeyframeAnimation *revenant_spring_keyframes(CABasicAnimation *animation, CALayer *layer, NSTimeInterval duration,
                                               RevenantSpringProgress progress, void *context, BOOL snapToEnd);

#endif
