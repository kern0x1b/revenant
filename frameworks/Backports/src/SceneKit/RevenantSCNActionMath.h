#import <SceneKit/SceneKit.h>

void RevenantSCNActionTimingPoints(SCNActionTimingMode mode, double points[4]);
double RevenantSCNActionCubicProgress(double progress, double x1, double y1, double x2, double y2);
double RevenantSCNActionEase(double progress, SCNActionTimingMode mode);
double RevenantSCNActionShortestAngle(double from, double to);
