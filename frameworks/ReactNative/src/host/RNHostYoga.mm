#import "RNHostYoga.h"

float RNHostYogaProbeWidth(void)
{
    YGNodeRef root = YGNodeNew();
    YGNodeStyleSetWidth(root, 320);
    YGNodeStyleSetHeight(root, 480);
    YGNodeCalculateLayout(root, YGUndefined, YGUndefined, YGDirectionLTR);
    float width = YGNodeLayoutGetWidth(root);
    YGNodeFree(root);
    return width;
}
