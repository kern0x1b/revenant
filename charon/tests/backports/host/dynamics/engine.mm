// engine.mm — reads our Box2D world for the tests, which are Objective-C and cannot include Box2D's C++
// headers. Only public Box2D 2.2.1 getters; every value in b2 units (metres, radians, kg).
#include <Box2D/Box2D.h>
#import "engine.h"

extern "C" {

EngineVector engine_world_gravity(void *world)
{
    b2Vec2 gravity = static_cast<b2World *>(world)->GetGravity();
    return (EngineVector){gravity.x, gravity.y};
}

int engine_body_count(void *world)
{
    return static_cast<b2World *>(world)->GetBodyCount();
}

int engine_joint_count(void *world)
{
    return static_cast<b2World *>(world)->GetJointCount();
}

// World order is newest first (b2World::CreateJoint pushes to the front of the list).
void *engine_joint(void *world, int index)
{
    b2Joint *joint = static_cast<b2World *>(world)->GetJointList();
    for (int each = 0; joint && each < index; each++)
        joint = joint->GetNext();
    return joint;
}

EngineJoint engine_joint_state(void *pointer)
{
    b2Joint *joint = static_cast<b2Joint *>(pointer);
    EngineJoint state = {};
    state.type = joint->GetType();
    state.collideConnected = joint->GetCollideConnected();
    switch (joint->GetType()) {
    case e_distanceJoint: {
        b2DistanceJoint *distance = static_cast<b2DistanceJoint *>(joint);
        state.localAnchorA = (EngineVector){distance->GetLocalAnchorA().x, distance->GetLocalAnchorA().y};
        state.localAnchorB = (EngineVector){distance->GetLocalAnchorB().x, distance->GetLocalAnchorB().y};
        state.length = distance->GetLength();
        state.frequency = distance->GetFrequency();
        state.dampingRatio = distance->GetDampingRatio();
        break;
    }
    case e_revoluteJoint: {
        b2RevoluteJoint *revolute = static_cast<b2RevoluteJoint *>(joint);
        state.localAnchorA = (EngineVector){revolute->GetLocalAnchorA().x, revolute->GetLocalAnchorA().y};
        state.localAnchorB = (EngineVector){revolute->GetLocalAnchorB().x, revolute->GetLocalAnchorB().y};
        state.referenceAngle = revolute->GetReferenceAngle();
        state.limitEnabled = revolute->IsLimitEnabled();
        state.lower = revolute->GetLowerLimit();
        state.upper = revolute->GetUpperLimit();
        state.motorEnabled = revolute->IsMotorEnabled();
        state.motorSpeed = revolute->GetMotorSpeed();
        state.maxMotor = revolute->GetMaxMotorTorque();
        break;
    }
    case e_prismaticJoint: {
        b2PrismaticJoint *prismatic = static_cast<b2PrismaticJoint *>(joint);
        state.localAnchorA = (EngineVector){prismatic->GetLocalAnchorA().x, prismatic->GetLocalAnchorA().y};
        state.localAnchorB = (EngineVector){prismatic->GetLocalAnchorB().x, prismatic->GetLocalAnchorB().y};
        state.localAxisA = (EngineVector){prismatic->GetLocalAxisA().x, prismatic->GetLocalAxisA().y};
        state.referenceAngle = prismatic->GetReferenceAngle();
        state.limitEnabled = prismatic->IsLimitEnabled();
        state.lower = prismatic->GetLowerLimit();
        state.upper = prismatic->GetUpperLimit();
        state.motorEnabled = prismatic->IsMotorEnabled();
        state.motorSpeed = prismatic->GetMotorSpeed();
        state.maxMotor = prismatic->GetMaxMotorForce();
        break;
    }
    case e_weldJoint: {
        b2WeldJoint *weld = static_cast<b2WeldJoint *>(joint);
        state.localAnchorA = (EngineVector){weld->GetLocalAnchorA().x, weld->GetLocalAnchorA().y};
        state.localAnchorB = (EngineVector){weld->GetLocalAnchorB().x, weld->GetLocalAnchorB().y};
        state.referenceAngle = weld->GetReferenceAngle();
        state.frequency = weld->GetFrequency();
        state.dampingRatio = weld->GetDampingRatio();
        break;
    }
    case e_ropeJoint: {
        b2RopeJoint *rope = static_cast<b2RopeJoint *>(joint);
        state.localAnchorA = (EngineVector){rope->GetLocalAnchorA().x, rope->GetLocalAnchorA().y};
        state.localAnchorB = (EngineVector){rope->GetLocalAnchorB().x, rope->GetLocalAnchorB().y};
        state.length = rope->GetMaxLength();
        break;
    }
    default:
        break;
    }
    return state;
}

EngineBody engine_body_state(void *pointer)
{
    b2Body *body = static_cast<b2Body *>(pointer);
    EngineBody state = {};
    state.type = body->GetType();
    state.mass = body->GetMass();
    state.inertia = body->GetInertia();
    state.bullet = body->IsBullet();
    state.awake = body->IsAwake();
    state.fixedRotation = body->IsFixedRotation();
    state.gravityScale = body->GetGravityScale();
    state.linearDamping = body->GetLinearDamping();
    state.angularDamping = body->GetAngularDamping();
    if (b2Fixture *fixture = body->GetFixtureList()) {
        state.friction = fixture->GetFriction();
        state.restitution = fixture->GetRestitution();
        state.density = fixture->GetDensity();
        state.radius = fixture->GetShape()->m_radius;
    }
    return state;
}

}
