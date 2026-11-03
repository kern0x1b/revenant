#include <yoga/Yoga.h>

#include <cmath>
#include <cstdio>

namespace {

int failures = 0;
int checks = 0;

void expectNear(const char* name, float actual, float expected) {
    bool passed = std::fabs(actual - expected) < 0.01f;
    checks++;
    if (!passed) {
        failures++;
    }
    std::printf("%s %s: %.2f (expected %.2f)\n", passed ? "PASS" : "FAIL", name, actual, expected);
}

YGSize measureLabel(YGNodeConstRef, float width, YGMeasureMode widthMode, float, YGMeasureMode) {
    YGSize size;
    size.width = widthMode == YGMeasureModeUndefined ? 50.0f : std::fmin(width, 50.0f);
    size.height = 18.0f;
    return size;
}

}

int main() {
    YGNodeRef root = YGNodeNew();
    YGNodeStyleSetWidth(root, 320);
    YGNodeStyleSetHeight(root, 480);
    YGNodeStyleSetFlexDirection(root, YGFlexDirectionColumn);
    YGNodeStyleSetPadding(root, YGEdgeAll, 10);

    YGNodeRef header = YGNodeNew();
    YGNodeStyleSetHeight(header, 40);
    YGNodeStyleSetMargin(header, YGEdgeBottom, 10);
    YGNodeInsertChild(root, header, 0);

    YGNodeRef row = YGNodeNew();
    YGNodeStyleSetFlexGrow(row, 1);
    YGNodeStyleSetFlexDirection(row, YGFlexDirectionRow);
    YGNodeStyleSetMargin(row, YGEdgeHorizontal, 5);
    YGNodeStyleSetPadding(row, YGEdgeAll, 4);
    YGNodeInsertChild(root, row, 1);

    YGNodeRef left = YGNodeNew();
    YGNodeStyleSetFlex(left, 1);
    YGNodeInsertChild(row, left, 0);

    YGNodeRef right = YGNodeNew();
    YGNodeStyleSetFlex(right, 1);
    YGNodeStyleSetFlexDirection(right, YGFlexDirectionColumn);
    YGNodeStyleSetAlignItems(right, YGAlignFlexStart);
    YGNodeInsertChild(row, right, 1);

    YGNodeRef label = YGNodeNew();
    YGNodeStyleSetMargin(label, YGEdgeTop, 3);
    YGNodeSetMeasureFunc(label, measureLabel);
    YGNodeInsertChild(right, label, 0);

    YGNodeCalculateLayout(root, 320, 480, YGDirectionLTR);

    expectNear("root width", YGNodeLayoutGetWidth(root), 320);
    expectNear("root height", YGNodeLayoutGetHeight(root), 480);
    expectNear("header left", YGNodeLayoutGetLeft(header), 10);
    expectNear("header top", YGNodeLayoutGetTop(header), 10);
    expectNear("header width", YGNodeLayoutGetWidth(header), 300);
    expectNear("header height", YGNodeLayoutGetHeight(header), 40);
    expectNear("row left", YGNodeLayoutGetLeft(row), 15);
    expectNear("row top", YGNodeLayoutGetTop(row), 60);
    expectNear("row width", YGNodeLayoutGetWidth(row), 290);
    expectNear("row height", YGNodeLayoutGetHeight(row), 410);
    expectNear("left child left", YGNodeLayoutGetLeft(left), 4);
    expectNear("left child top", YGNodeLayoutGetTop(left), 4);
    expectNear("left child width", YGNodeLayoutGetWidth(left), 141);
    expectNear("left child height", YGNodeLayoutGetHeight(left), 402);
    expectNear("right child left", YGNodeLayoutGetLeft(right), 145);
    expectNear("right child top", YGNodeLayoutGetTop(right), 4);
    expectNear("right child width", YGNodeLayoutGetWidth(right), 141);
    expectNear("right child height", YGNodeLayoutGetHeight(right), 402);
    expectNear("label top", YGNodeLayoutGetTop(label), 3);
    expectNear("label width", YGNodeLayoutGetWidth(label), 50);
    expectNear("label height", YGNodeLayoutGetHeight(label), 18);

    YGNodeFreeRecursive(root);

    if (failures == 0) {
        std::printf("PASS: %d checks\n", checks);
        return 0;
    }
    std::printf("FAIL: %d of %d checks\n", failures, checks);
    return 1;
}
