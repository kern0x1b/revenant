#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <math.h>

// CharonGKGraph.h -- the pathfinding half of GameplayKit: what its graphs need from each other.
// Nothing here is API. Every declaration is a CharonGK* name or carries a charon_ selector prefix, and
// modules/apple/backports.lua's internal_symbol() leaves both out of what it weighs a release against and
// out of what the library exports.

// --- the arithmetic the graphs share -----------------------------------------------------------------
// A straight line between two points, in the plane and in space. The distance is what a node charges to
// reach another, and the host's own numbers are these: two 2D nodes at (0,0) and (3,4) are 5 apart and
// two 3D nodes at the origin and (1,2,2) are 3 apart (tests/backports/host/gameplaykit-graph/differential.m).
static inline float CharonGKLength2(vector_float2 from, vector_float2 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    return (float)sqrt((double)(dx * dx + dy * dy));
}

static inline float CharonGKLength3(vector_float3 from, vector_float3 to)
{
    float dx = to.x - from.x;
    float dy = to.y - from.y;
    float dz = to.z - from.z;
    return (float)sqrt((double)(dx * dx + dy * dy + dz * dz));
}

// The distance between two cells of a grid graph, which is what a grid node charges instead of a length:
// measured (0,0) to (1,1) is 1.41421 and (2,3) to (1,1) is 2.23607, both sqrt(2).
static inline float CharonGKCellDistance(vector_int2 from, vector_int2 to)
{
    float dx = (float)(to.x - from.x);
    float dy = (float)(to.y - from.y);
    return (float)sqrt((double)(dx * dx + dy * dy));
}

// The cell size a spatial index actually uses, given the minimum the caller gave and the extent of the box.
// The minimum is a FLOOR on the size, not the size: the tree halves, so the sizes it can take are the powers
// of two, and the smallest power of two at or above the minimum is the one it settles on. Measured, a
// minimum of 3 in a box of extent 8 files (7.9,7.9,7.9) in the cell 4..8; a minimum of 2 files
// (1.9,1.9,1.9) in 0..2; a minimum of 1 files (5.5,5.5,5.5) in 5..6; a minimum of 0.5 files (3.3,0,0) in
// 3..3.5; a minimum of 16, wider than the box, in the whole box 0..8.
float CharonGKCellSize(float minimum, float extent);

// The cell edge below a point and the cell edge above it, both multiples of the size the index settled on.
float CharonGKCellFloor(float value, float size);
float CharonGKCellCeiling(float value, float size, float limit);

// The NODE an element is filed in, one level above the cell its low corner falls in, so its size is twice
// the cell size. Measured on the host and written out at the definition in CharonGKGraph.m.
float CharonGKNodeSize(float cellSize);

// A node's far edge, never past the box it indexes.
float CharonGKNodeCeiling(float edge, float limit);

// The node an element is filed in: one level above the cell its low corner falls in, so its size is twice
// the cell size. Measured on the host and recorded in CharonGKGraph.m above the function.

// --- the geometry an obstacle stands for --------------------------------------------------------------
// Is a point inside the closed polygon an obstacle gives? The rule is the standard even-odd crossing
// count: a ray from the point upwards crosses a side when the side straddles the point's row and the
// crossing falls to the side the ray is cast towards. Half-open on both ends, so a vertex on the ray
// counts once and never twice, which is what makes the answer exact on the host's own polygons: a
// square {(0,0),(4,0),(4,4),(0,4)} contains (2,2) and not (5,2), and with a buffer radius of 1 it also
// contains (4.5,2) and not (5.5,2).
BOOL CharonGKPointInPolygon(vector_float2 point, const vector_float2 *vertices, NSUInteger count,
                            float buffer);

// Is a point exactly on an obstacle's boundary? An obstacle graph's own corners are, and the rule that an
// edge ending inside an obstacle is blocked has to let them through or the graph has no edges at all.
BOOL CharonGKPointOnBoundary(vector_float2 point, const vector_float2 *vertices, NSUInteger count);

// Does the straight line between two nodes cross the boundary of a polygon? This is the question an
// obstacle graph asks before it keeps an edge, and it is what cuts the graph into the regions the
// obstacle separates. Both ends inside is not a crossing: the line between two points of one region
// stays in it, so the edge is kept and the search never leaves.
BOOL CharonGKSegmentCrossesPolygon(vector_float2 from, vector_float2 to, const vector_float2 *vertices,
                                   NSUInteger count, float buffer);

// --- the one search every find of this family reaches -------------------------------------------------
// One A* pass, from one node to another, over the edges the nodes themselves hold. It answers the path
// in start-to-end order with both ends in it, or nil when there is none -- measured on the host: a
// three-node chain answers four nodes, a node asked for a path to itself answers itself alone, and a
// target that cannot be reached answers an empty array.
//
// The state one pass carries hangs off the node as an associated object rather than as an ivar, so that
// the 9.0 object of this family and the 10.0 one -- which are separate files, because an object holds
// the API of exactly one release -- can share this one search without either naming the other's storage.
NSArray *CharonGKFindPath(NSArray *nodes, id start, id goal);

// What one spatial index of this framework files in one cell: the element, the region it occupies, and
// whether it was given a point rather than a region. A point element answers for its whole cell -- that
// is measured, and it is why a lookup is the cell followed by this test rather than the cell alone -- and
// a region element answers only where its region holds the point.
//
// It is a CharonGK* class and so is not API: internal_symbol() in modules/apple/backports.lua leaves a
// name that begins with Charon out of what a band is weighed against and out of what the library exports.
// The ivars are public because the two indexes that file entries read them directly, and they are named
// charon_ so that no accessor of the framework's surface grows for them.
@interface CharonGKEntry : NSObject {
@public
    id charon_element;
    vector_float3 charon_min;
    vector_float3 charon_max;
    BOOL charon_isPoint;
}

+ (instancetype)charon_entryWithElement:(id)element low:(vector_float3)low high:(vector_float3)high
                               isPoint:(BOOL)isPoint;

// Does a point fall inside this entry? A point entry's region is its own cell and a region entry's is its
// own region, so the one test covers both.
- (BOOL)charon_holdsPoint:(vector_float3)point;

// Does a 2D range meet this entry's? A quad and a rectangle are the first two components of the same
// region a box is, so one test covers all three.
- (BOOL)charon_meetsRange:(vector_float2)low high:(vector_float2)high;

@end


// The two accessors that pass needs from a node, which are the node's own API read through the runtime so
// that this file does not have to import the framework's headers: -connectedNodes and the two cost
// methods. A node of this family answers all three, and the ones that carry a position answer the cost
// as the length of the line between the two.
NSArray *CharonGKConnected(id node);
float CharonGKSearchScore(id node);
float CharonGKCostTo(id from, id to);

// --- three boxes of the port's own, because a vector type cannot go through NSValue ------------------------
// @encode cannot describe a vector type -- clang says "component has unknown encoding" -- and -getValue:size:
// is iOS 11 while this library is carried for 6.0. So the geometry this family passes around is in three
// small CharonGK* classes with public ivars, not in NSValues over bytes. They are not API: internal_symbol()
// leaves a name beginning with Charon out of what a band is weighed against and out of what the library
// exports, and no SDK header declares one of them.
@interface CharonGKPoint2 : NSObject {
@public
    vector_float2 point;
}
+ (instancetype)pointWithX:(float)x y:(float)y;
- (vector_float2)vector;
@end

@interface CharonGKTriangle3 : NSObject {
@public
    vector_float3 points[3];
}
+ (instancetype)triangleAt:(vector_float2)a first:(vector_float2)b second:(vector_float2)c;
@end

@interface CharonGKEdgePair : NSObject {
@public
    NSUInteger first;
    NSUInteger second;
}
+ (instancetype)pairWithFirst:(NSUInteger)first second:(NSUInteger)second;
@end

// The one place a node is made out of a class the caller named rather than out of the class the code knows.
// GKGraphNode2D and GKGraphNode3D both declare -initWithPoint: and take different vectors, so a message to a
// Class is ambiguous exactly where the header itself is; the initialiser is taken by name and called through
// its own type. A class that declares neither answers nil, which is what -nodeAtGridPosition: and the two
// graph factories then leave in their answer.
id CharonGKPointNodeWithClass(Class nodeClass, vector_float2 point);

// --- the two triangulations this family builds --------------------------------------------------------
// The free space of a mesh graph: a rectangle with the buffered obstacles cut out of it, which is a
// polygon with holes. Both are returned as a list of triangles over the region's own vertices, in the
// order the region's outline gave them, which is what -triangleAtIndex: and the node list both read.
NSArray *CharonGKTriangulateRegion(NSArray *outline, NSArray *holes);

// The corners an obstacle grows to when it is buffered: every vertex of every obstacle, pushed out along
// its own two edges by the buffer radius and cut back where two of them cross. The order is the order the
// obstacles and their vertices were given in, so the node list of an obstacle graph answers its obstacles
// in the order the caller added them.
NSArray *CharonGKBufferedCorners(NSArray *obstacles, float buffer, NSMutableArray *perObstacle);

// The edges of the visibility graph over those corners: two corners are joined when the line between
// them meets no obstacle at all, which is what makes the graph a path a path may take round them.
NSArray *CharonGKVisibilityEdges(NSArray *corners, NSArray *obstacles, float buffer);

// What an obstacle contributes to a triangulation: its own vertices in the order they were given.
NSArray *CharonGKVerticesOfObstacle(id obstacle);

// The keys that state is filed under, and the four graphs' archive keys. An archive of a graph carries
// its nodes as the class each is, plus that class's own position and no state of the port's own, so that
// a decoded graph is the graph that was encoded.
extern NSString *const CharonGKSearchClosedKey;
extern NSString *const CharonGKSearchScoreKey;
extern NSString *const CharonGKSearchParentKey;
extern NSString *const CharonGKGraphNodesKey;
extern NSString *const CharonGKGraphNodeClassKey;
extern NSString *const CharonGKGraphNodePositionKey;
extern NSString *const CharonGKObstacleVerticesKey;
extern NSString *const CharonGKObstacleGraphObstaclesKey;
extern NSString *const CharonGKObstacleGraphBufferKey;
extern NSString *const CharonGKObstacleGraphLocksKey;