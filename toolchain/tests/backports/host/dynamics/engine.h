#include <stdbool.h>

typedef struct { float x, y; } EngineVector;

typedef struct {
    int type;
    bool collideConnected;
    EngineVector localAnchorA, localAnchorB, localAxisA;
    float length, frequency, dampingRatio, referenceAngle;
    bool limitEnabled, motorEnabled;
    float lower, upper, motorSpeed, maxMotor;
} EngineJoint;

typedef struct {
    int type;
    float mass, inertia, gravityScale, linearDamping, angularDamping;
    bool bullet, awake, fixedRotation;
    float friction, restitution, density, radius;
} EngineBody;

enum { EngineRevolute = 1, EnginePrismatic = 2, EngineDistance = 3, EngineWeld = 8, EngineRope = 10 };

#ifdef __cplusplus
extern "C" {
#endif
EngineVector engine_world_gravity(void *world);
int engine_body_count(void *world);
int engine_joint_count(void *world);
void *engine_joint(void *world, int index);
EngineJoint engine_joint_state(void *joint);
EngineBody engine_body_state(void *body);
#ifdef __cplusplus
}
#endif
