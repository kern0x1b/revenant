#ifndef REVENANT_SWITCH_GEOMETRY_H
#define REVENANT_SWITCH_GEOMETRY_H

#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>

typedef struct {
    double mass;
    double stiffness;
    double damping;
    double duration;
} RevenantSwitchSpring;

typedef struct {
    bool on;
    bool displayedOn;
    bool panning;
    CGFloat touchX;
    CGFloat anchorX;
} RevenantSwitchTracking;

CG_EXTERN const CGSize RevenantSwitchSize;
CG_EXTERN const CGFloat RevenantSwitchAlignmentRight;
CG_EXTERN const CGFloat RevenantSwitchOffComponents[4];
CG_EXTERN const CGFloat RevenantSwitchOnComponents[4];
CG_EXTERN const CGFloat RevenantSwitchDisabledAlpha;
CG_EXTERN const RevenantSwitchSpring RevenantSwitchKnobSpring;
CG_EXTERN const RevenantSwitchSpring RevenantSwitchWellOnSpring;
CG_EXTERN const RevenantSwitchSpring RevenantSwitchWellOffSpring;

CG_EXTERN CGRect RevenantSwitchKnobBounds(bool pressed);
CG_EXTERN CGPoint RevenantSwitchKnobPosition(bool on, bool pressed);
CG_EXTERN CGRect RevenantSwitchKnobContentsCenter(void);
CG_EXTERN CGRect RevenantSwitchWellFrame(bool on);
CG_EXTERN CGFloat RevenantSwitchWellAlpha(CGFloat x);
CG_EXTERN CGRect RevenantSwitchKnobTrackRect(bool on);
CG_EXTERN CGImageRef RevenantSwitchKnobImageCreate(CGColorRef fill, CGFloat scale, bool on);
CG_EXTERN CGImageRef RevenantSwitchWellImageCreate(CGColorRef color, CGFloat scale);

CG_EXTERN void RevenantSwitchTrackingBegin(RevenantSwitchTracking *tracking, bool on, CGFloat x);
CG_EXTERN bool RevenantSwitchTrackingMove(RevenantSwitchTracking *tracking, CGFloat x);
CG_EXTERN bool RevenantSwitchTrackingEnd(RevenantSwitchTracking *tracking, bool inside);

#endif
