// The SKNode tree of iOS 7, the port against the host's own SpriteKit, over the same scenarios. The program reaches the
// class only through the Objective-C runtime (NSClassFromString and objc_msgSend), so the same source builds against the
// host's SpriteKit framework (the oracle) and against the port's objects with no SpriteKit framework linked. Nothing
// here writes an expected value: each scenario prints what the class answers or which exception it raises, and run.sh
// compares the two runs line by line.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef id (*Maker)(id, SEL);
typedef id (*Named)(id, SEL, NSString *);
typedef id (*Init)(id, SEL);
typedef void (*VoidObject)(id, SEL, id);
typedef void (*VoidObjectIndex)(id, SEL, id, NSUInteger);
typedef void (*VoidVoid)(id, SEL);
typedef void (*VoidCGFloat)(id, SEL, CGFloat);
typedef void (*VoidPoint)(id, SEL, CGPoint);
typedef void (*VoidBool)(id, SEL, BOOL);
typedef void (*VoidArray)(id, SEL, NSArray *);
typedef void (*VoidEnumerate)(id, SEL, NSString *, void (^)(id, BOOL *));
typedef id (*ObjectGetter)(id, SEL);
typedef id (*ObjectWithObject)(id, SEL, id);
typedef NSUInteger (*UIntGetter)(id, SEL);
typedef CGFloat (*FloatGetter)(id, SEL);
typedef BOOL (*BoolGetter)(id, SEL);
typedef CGRect (*RectGetter)(id, SEL);
typedef CGPoint (*PointGetter)(id, SEL);
typedef CGPoint (*ConvertFrom)(id, SEL, CGPoint, id);
typedef BOOL (*BoolWithObject)(id, SEL, id);
typedef BOOL (*BoolWithPoint)(id, SEL, CGPoint);
typedef id (*ObjectWithPoint)(id, SEL, CGPoint);
typedef NSArray *(*ArrayWithPoint)(id, SEL, CGPoint);
typedef id (*ObjectWithPointName)(id, SEL, id);

static Class nodeClass;

static SEL S(const char *name)
{
    return sel_registerName(name);
}

static NSString *describe(id object)
{
    if (object == nil) return @"nil";
    NSString *name = ((ObjectGetter)objc_msgSend)(object, S("name"));
    return [NSString stringWithFormat:@"%@", name ? name : @"(no name)"];
}

static NSString *names(NSArray *nodes)
{
    NSMutableArray *out = [NSMutableArray array];
    for (id node in nodes) {
        [out addObject:describe(node)];
    }
    return [NSString stringWithFormat:@"[%@]", [out componentsJoinedByString:@","]];
}

static id node(NSString *name)
{
    id n = ((Maker)objc_msgSend)(nodeClass, S("node"));
    ((VoidObject)objc_msgSend)(n, S("setName:"), name);
    return n;
}

static void add(id parent, id child)
{
    ((VoidObject)objc_msgSend)(parent, S("addChild:"), child);
}

static void report(const char *label, void (^body)(void))
{
    @try {
        body();
    } @catch (NSException *e) {
        printf("%s: raised %s\n", label, [e.name UTF8String]);
    }
}

static void rect(const char *label, CGRect r)
{
    printf("%s: {%.9g,%.9g,%.9g,%.9g}\n", label, r.origin.x, r.origin.y, r.size.width, r.size.height);
}

static void point(const char *label, CGPoint p)
{
    printf("%s: (%.9g,%.9g)\n", label, p.x, p.y);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        nodeClass = NSClassFromString(@"SKNode");
        if (nodeClass == Nil) {
            printf("SKNode: absent\n");
            return 1;
        }

        // Defaults of a plain node.
        id plain = ((Maker)objc_msgSend)(nodeClass, S("node"));
        printf("class=%s\n", class_getName([plain class]));
        printf("name=%s\n", [describe(plain) UTF8String]);
        printf("name nil=%d\n", ((ObjectGetter)objc_msgSend)(plain, S("name")) == nil);
        point("position", ((PointGetter)objc_msgSend)(plain, S("position")));
        printf("zPosition=%.9g zRotation=%.9g xScale=%.9g yScale=%.9g\n",
               ((FloatGetter)objc_msgSend)(plain, S("zPosition")), ((FloatGetter)objc_msgSend)(plain, S("zRotation")),
               ((FloatGetter)objc_msgSend)(plain, S("xScale")), ((FloatGetter)objc_msgSend)(plain, S("yScale")));
        printf("alpha=%.9g speed=%.9g paused=%d hidden=%d userInteractionEnabled=%d\n",
               ((FloatGetter)objc_msgSend)(plain, S("alpha")), ((FloatGetter)objc_msgSend)(plain, S("speed")),
               ((BoolGetter)objc_msgSend)(plain, S("isPaused")), ((BoolGetter)objc_msgSend)(plain, S("isHidden")),
               ((BoolGetter)objc_msgSend)(plain, S("isUserInteractionEnabled")));
        printf("parent nil=%d children=%lu userData nil=%d\n",
               ((ObjectGetter)objc_msgSend)(plain, S("parent")) == nil,
               (unsigned long)[((ObjectGetter)objc_msgSend)(plain, S("children")) count],
               ((ObjectGetter)objc_msgSend)(plain, S("userData")) == nil);
        rect("frame", ((RectGetter)objc_msgSend)(plain, S("frame")));
        rect("calculateAccumulatedFrame", ((RectGetter)objc_msgSend)(plain, S("calculateAccumulatedFrame")));

        // A tree: root > a > x > y, root > b, root > b (second b), root > c.
        id root = node(@"root");
        id a = node(@"a");
        id x = node(@"x");
        id y = node(@"y");
        id b = node(@"b");
        id b2 = node(@"b");
        id c = node(@"c");
        add(root, a);
        add(a, x);
        add(x, y);
        add(root, b);
        add(root, b2);
        add(root, c);
        printf("children=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);
        printf("a.parent=%s x.parent=%s\n", [describe(((ObjectGetter)objc_msgSend)(a, S("parent"))) UTF8String],
               [describe(((ObjectGetter)objc_msgSend)(x, S("parent"))) UTF8String]);
        printf("inParentHierarchy: y in root=%d root in y=%d a in root=%d\n",
               ((BoolWithObject)objc_msgSend)(y, S("inParentHierarchy:"), root),
               ((BoolWithObject)objc_msgSend)(root, S("inParentHierarchy:"), y),
               ((BoolWithObject)objc_msgSend)(a, S("inParentHierarchy:"), root));
        printf("inParentHierarchy: nil=%d\n", ((BoolWithObject)objc_msgSend)(a, S("inParentHierarchy:"), nil));

        // Names and search.
        printf("childNodeWithName:b=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"b")) UTF8String]);
        printf("childNodeWithName:x (not a child)=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"x")) UTF8String]);
        printf("childNodeWithName:a/x=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"a/x")) UTF8String]);
        printf("childNodeWithName://y=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"//y")) UTF8String]);
        printf("childNodeWithName://x=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"//x")) UTF8String]);
        printf("childNodeWithName:a/x/y=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"a/x/y")) UTF8String]);
        printf("childNodeWithName:*=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"*")) UTF8String]);
        printf("childNodeWithName:c.=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"c.")) UTF8String]);
        printf("childNodeWithName:.=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @".")) UTF8String]);
        printf("childNodeWithName:a/../b=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"a/../b")) UTF8String]);
        printf("childNodeWithName:a/.=%s\n", [describe(((ObjectWithPointName)objc_msgSend)(root, S("childNodeWithName:"), @"a/.")) UTF8String]);
        printf("subscript:b=%s\n", [names(((ObjectWithPointName)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"b")) UTF8String]);
        printf("subscript://y=%s\n", [names(((ObjectWithPointName)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"//y")) UTF8String]);
        printf("subscript:*=%s\n", [names(((ObjectWithPointName)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"*")) UTF8String]);
        printf("subscript:none=%s\n", [names(((ObjectWithPointName)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"none")) UTF8String]);
        printf("subscript://b=%s\n", [names(((ObjectWithPointName)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"//b")) UTF8String]);

        __block NSMutableArray *seen = [NSMutableArray array];
        ((VoidEnumerate)objc_msgSend)(root, S("enumerateChildNodesWithName:usingBlock:"), @"b", ^(id n, BOOL *stop) {
            [seen addObject:describe(n)];
        });
        printf("enumerate:b=[%s]\n", [[seen componentsJoinedByString:@","] UTF8String]);
        seen = [NSMutableArray array];
        ((VoidEnumerate)objc_msgSend)(root, S("enumerateChildNodesWithName:usingBlock:"), @"//y", ^(id n, BOOL *stop) {
            [seen addObject:describe(n)];
        });
        printf("enumerate://y=[%s]\n", [[seen componentsJoinedByString:@","] UTF8String]);
        seen = [NSMutableArray array];
        ((VoidEnumerate)objc_msgSend)(root, S("enumerateChildNodesWithName:usingBlock:"), @"b", ^(id n, BOOL *stop) {
            [seen addObject:describe(n)];
            *stop = YES;
        });
        printf("enumerate:b stop=[%s]\n", [[seen componentsJoinedByString:@","] UTF8String]);

        // Order: insert at index, moves, removal.
        id d = node(@"d");
        ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), d, 0);
        printf("insert d at 0=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);

        id e = node(@"e");
        add(root, e);
        report("addChild: e again", ^{ add(root, e); });
        printf("add e twice=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);
        printf("e.parent=%s\n", [describe(((ObjectGetter)objc_msgSend)(e, S("parent"))) UTF8String]);

        report("addChild:nil", ^{ add(root, nil); });
        report("addChild:self", ^{ add(root, root); });
        report("addChild: ancestor", ^{ add(y, root); });

        // Reparenting moves the node.
        report("addChild: d already parented", ^{ add(b, d); });
        printf("after add d to b: root=%s b=%s d.parent=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String],
               [names(((ObjectGetter)objc_msgSend)(b, S("children"))) UTF8String],
               [describe(((ObjectGetter)objc_msgSend)(d, S("parent"))) UTF8String]);
        ((VoidObject)objc_msgSend)(c, S("moveToParent:"), a);
        printf("after moveToParent c->a: root=%s a=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String],
               [names(((ObjectGetter)objc_msgSend)(a, S("children"))) UTF8String]);
        ((VoidVoid)objc_msgSend)(c, S("removeFromParent"));
        printf("after removeFromParent c: a=%s c.parent nil=%d\n", [names(((ObjectGetter)objc_msgSend)(a, S("children"))) UTF8String],
               ((ObjectGetter)objc_msgSend)(c, S("parent")) == nil);
        ((VoidVoid)objc_msgSend)(plain, S("removeFromParent"));
        printf("removeFromParent with no parent: ok\n");

        ((VoidArray)objc_msgSend)(root, S("removeChildrenInArray:"), @[ x, c ]);
        printf("removeChildrenInArray [x,c] (x not a child of root)=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);
        ((VoidArray)objc_msgSend)(root, S("removeChildrenInArray:"), @[ e ]);
        printf("removeChildrenInArray [e]=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);
        printf("e.parent nil=%d\n", ((ObjectGetter)objc_msgSend)(e, S("parent")) == nil);

        // Geometry.
        id g = node(@"g");
        ((VoidPoint)objc_msgSend)(g, S("setPosition:"), CGPointMake(10, 20));
        ((VoidCGFloat)objc_msgSend)(g, S("setZRotation:"), 0);
        id h = node(@"h");
        ((VoidPoint)objc_msgSend)(h, S("setPosition:"), CGPointMake(5, 5));
        add(g, h);
        add(root, g);
        point("convertPoint:(0,0) from h to root", ((ConvertFrom)objc_msgSend)(root, S("convertPoint:fromNode:"), CGPointMake(0, 0), h));
        point("convertPoint:(0,0) from root to h", ((ConvertFrom)objc_msgSend)(root, S("convertPoint:toNode:"), CGPointMake(0, 0), h));
        point("convertPoint:(1,2) from h to g", ((ConvertFrom)objc_msgSend)(g, S("convertPoint:fromNode:"), CGPointMake(1, 2), h));
        ((VoidCGFloat)objc_msgSend)(g, S("setXScale:"), 2);
        ((VoidCGFloat)objc_msgSend)(g, S("setYScale:"), 3);
        point("scaled convertPoint:(1,2) from h to root", ((ConvertFrom)objc_msgSend)(root, S("convertPoint:fromNode:"), CGPointMake(1, 2), h));
        ((VoidCGFloat)objc_msgSend)(g, S("setZRotation:"), M_PI / 2);
        point("rotated convertPoint:(1,0) from h to root", ((ConvertFrom)objc_msgSend)(root, S("convertPoint:fromNode:"), CGPointMake(1, 0), h));
        ((VoidCGFloat)objc_msgSend)(g, S("setZRotation:"), 0);
        ((VoidCGFloat)objc_msgSend)(g, S("setXScale:"), 1);
        ((VoidCGFloat)objc_msgSend)(g, S("setYScale:"), 1);
        ((VoidCGFloat)objc_msgSend)(g, S("setScale:"), 2);
        printf("setScale:2 xScale=%.9g yScale=%.9g\n", ((FloatGetter)objc_msgSend)(g, S("xScale")), ((FloatGetter)objc_msgSend)(g, S("yScale")));
        ((VoidCGFloat)objc_msgSend)(g, S("setScale:"), 1);
        ((VoidCGFloat)objc_msgSend)(g, S("setZPosition:"), 4.5);
        printf("zPosition=%.9g\n", ((FloatGetter)objc_msgSend)(g, S("zPosition")));
        printf("containsPoint: plain=%d\n", ((BoolWithPoint)objc_msgSend)(plain, S("containsPoint:"), CGPointMake(0, 0)));
        printf("nodeAtPoint: plain=%s\n", describe(((ObjectWithPoint)objc_msgSend)(plain, S("nodeAtPoint:"), CGPointMake(0, 0))).UTF8String);
        printf("nodesAtPoint: plain=%s\n", names(((ArrayWithPoint)objc_msgSend)(plain, S("nodesAtPoint:"), CGPointMake(0, 0))).UTF8String);
        printf("intersectsNode: plain/plain=%d\n", ((BoolWithObject)objc_msgSend)(plain, S("intersectsNode:"), node(@"p")));
        printf("isEqualToNode: self=%d other=%d\n", ((BoolWithObject)objc_msgSend)(plain, S("isEqualToNode:"), plain),
               ((BoolWithObject)objc_msgSend)(plain, S("isEqualToNode:"), node(@"plain")));
        printf("isEqual: node=%d\n", [plain isEqual:plain]);

        // Frames and hit tests of a plain tree: positions only, no content.
        id framed = node(@"framed");
        ((VoidPoint)objc_msgSend)(framed, S("setPosition:"), CGPointMake(10, 20));
        id framedChild = node(@"framedChild");
        ((VoidPoint)objc_msgSend)(framedChild, S("setPosition:"), CGPointMake(5, 7));
        add(framed, framedChild);
        rect("frame of framed", ((RectGetter)objc_msgSend)(framed, S("frame")));
        rect("accumulated of framed", ((RectGetter)objc_msgSend)(framed, S("calculateAccumulatedFrame")));
        rect("frame of framedChild", ((RectGetter)objc_msgSend)(framedChild, S("frame")));
        printf("nodeAtPoint: framed (10,20)=%s\n", describe(((ObjectWithPoint)objc_msgSend)(framed, S("nodeAtPoint:"), CGPointMake(10, 20))).UTF8String);
        printf("nodeAtPoint: framed (15,27)=%s\n", describe(((ObjectWithPoint)objc_msgSend)(framed, S("nodeAtPoint:"), CGPointMake(15, 27))).UTF8String);
        printf("nodesAtPoint: framed (15,27) count=%lu\n", (unsigned long)[((ArrayWithPoint)objc_msgSend)(framed, S("nodesAtPoint:"), CGPointMake(15, 27)) count]);
        printf("intersectsNode: framed/child=%d\n", ((BoolWithObject)objc_msgSend)(framed, S("intersectsNode:"), framedChild));
        printf("containsPoint: framed (10,20)=%d\n", ((BoolWithPoint)objc_msgSend)(framed, S("containsPoint:"), CGPointMake(10, 20)));
        printf("convertPoint:(0,0) framedChild->framed=");
        point("", ((ConvertFrom)objc_msgSend)(framed, S("convertPoint:fromNode:"), CGPointMake(0, 0), framedChild));
        printf("convertPoint:(0,0) framed->framedChild=");
        point("", ((ConvertFrom)objc_msgSend)(framed, S("convertPoint:toNode:"), CGPointMake(0, 0), framedChild));
        printf("name lookup from child: %s\n", describe(((ObjectWithPointName)objc_msgSend)(framedChild, S("childNodeWithName:"), @"framedChild")).UTF8String);

        // Name grammar beyond the plain forms.
        id grammar = node(@"g0");
        id gb1 = node(@"b1");
        id gb2 = node(@"bb");
        id gq = node(@"q");
        id gdeep = node(@"deep");
        add(grammar, gb1);
        add(grammar, gb2);
        add(grammar, gq);
        add(gq, gdeep);
        printf("grammar b* child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"b*")).UTF8String);
        printf("grammar ? child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"?")).UTF8String);
        printf("grammar b? child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"b?")).UTF8String);
        printf("grammar //* child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"//*")).UTF8String);
        printf("grammar //deep=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"//deep")).UTF8String);
        printf("grammar q//deep=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"q//deep")).UTF8String);
        printf("grammar q/ =%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"q/")).UTF8String);
        printf("grammar /q=%s\n", describe(((ObjectWithPointName)objc_msgSend)(grammar, S("childNodeWithName:"), @"/q")).UTF8String);
        printf("grammar subscript b*=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"b*")) UTF8String]);
        printf("grammar subscript //*=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"//*")) UTF8String]);
        printf("grammar subscript //b=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"//b")) UTF8String]);
        printf("grammar subscript q/deep=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"q/deep")) UTF8String]);
        printf("grammar subscript *=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"*")) UTF8String]);
        printf("grammar subscript //deep=%s\n", [names(((ObjectWithPointName)objc_msgSend)(grammar, S("objectForKeyedSubscript:"), @"//deep")) UTF8String]);

        // Descendant order: depth first, or breadth first.
        id order = node(@"order");
        id oq = node(@"q");
        id oz = node(@"z");
        add(order, oq);
        add(order, oz);
        add(oq, node(@"deep"));
        printf("order //* subscript=%s\n", [names(((ObjectWithPointName)objc_msgSend)(order, S("objectForKeyedSubscript:"), @"//*")) UTF8String]);
        printf("order //* child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(order, S("childNodeWithName:"), @"//*")).UTF8String);
        printf("order ? subscript=%s\n", [names(((ObjectWithPointName)objc_msgSend)(order, S("objectForKeyedSubscript:"), @"?")) UTF8String]);
        printf("order q// trailing=%s\n", describe(((ObjectWithPointName)objc_msgSend)(order, S("childNodeWithName:"), @"q//")).UTF8String);

        // An intermediate step that matches several nodes.
        id multi = node(@"multi");
        id m1 = node(@"b1");
        id m2 = node(@"b2");
        add(multi, m1);
        add(multi, m2);
        add(m1, node(@"x"));
        add(m2, node(@"x"));
        printf("multi b*/x subscript=%s\n", [names(((ObjectWithPointName)objc_msgSend)(multi, S("objectForKeyedSubscript:"), @"b*/x")) UTF8String]);
        printf("multi b*/x child=%s\n", describe(((ObjectWithPointName)objc_msgSend)(multi, S("childNodeWithName:"), @"b*/x")).UTF8String);
        printf("multi ../multi=%s\n", describe(((ObjectWithPointName)objc_msgSend)(m1, S("childNodeWithName:"), @"../b2")).UTF8String);
        printf("multi ./b1=%s\n", describe(((ObjectWithPointName)objc_msgSend)(multi, S("childNodeWithName:"), @"./b1")).UTF8String);
        printf("order a//b with empty=%s\n", describe(((ObjectWithPointName)objc_msgSend)(order, S("childNodeWithName:"), @"q//z")).UTF8String);

        // userData and children snapshots.
        id user = [NSMutableDictionary dictionary];
        ((VoidObject)objc_msgSend)(plain, S("setUserData:"), user);
        printf("userData set=%d\n", ((ObjectGetter)objc_msgSend)(plain, S("userData")) != nil);
        NSArray *snapshot = ((ObjectGetter)objc_msgSend)(root, S("children"));
        NSUInteger before = [snapshot count];
        add(root, node(@"late"));
        printf("snapshot unchanged=%d\n", [snapshot count] == before);

        // removeAllChildren.
        ((VoidVoid)objc_msgSend)(root, S("removeAllChildren"));
        printf("removeAllChildren=%s\n", [names(((ObjectGetter)objc_msgSend)(root, S("children"))) UTF8String]);
        printf("b.parent with root cleared=%s\n", [describe(((ObjectGetter)objc_msgSend)(b, S("parent"))) UTF8String]);
    }
    return 0;
}
