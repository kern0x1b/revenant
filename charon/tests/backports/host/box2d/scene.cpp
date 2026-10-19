// One scene over every part of Box2D 2.2.1 UIKit Dynamics reaches: polygons and circles on edges,
// a stack that falls asleep, a bullet, the five joint types PhysicsKit carries (revolute, distance,
// weld, prismatic, rope), contacts, damping, and the fixed sub-step loop of PhysicsKit's world.
// Prints every body's state as hexadecimal floats, so two builds compare bit for bit.
#include <Box2D/Box2D.h>
#include <math.h>
#include <stdio.h>

static b2Body *box(b2World &world, float x, float y, float hx, float hy, float angle)
{
    b2BodyDef def;
    def.type = b2_dynamicBody;
    def.position.Set(x, y);
    def.angle = angle;
    def.linearDamping = 0.1f;
    def.angularDamping = 0.1f;
    b2Body *body = world.CreateBody(&def);
    b2PolygonShape shape;
    shape.SetAsBox(hx, hy);
    b2FixtureDef fixture;
    fixture.shape = &shape;
    fixture.density = 1.0f;
    fixture.friction = 0.2f;
    fixture.restitution = 0.2f;
    body->CreateFixture(&fixture);
    return body;
}

static b2Body *ball(b2World &world, float x, float y, float radius)
{
    b2BodyDef def;
    def.type = b2_dynamicBody;
    def.position.Set(x, y);
    b2Body *body = world.CreateBody(&def);
    b2CircleShape shape;
    shape.m_radius = radius;
    body->CreateFixture(&shape, 2.0f);
    return body;
}

static void print(b2World &world, int step)
{
    int index = 0;
    for (b2Body *body = world.GetBodyList(); body; body = body->GetNext(), index++) {
        const b2Vec2 &p = body->GetPosition();
        const b2Vec2 &v = body->GetLinearVelocity();
        printf("%d %d %a %a %a %a %a %a %d\n", step, index, p.x, p.y, body->GetAngle(), v.x, v.y,
               body->GetAngularVelocity(), body->IsAwake() ? 1 : 0);
    }
}

int main(void)
{
    b2World world(b2Vec2(0.0f, 10.0f));
    world.SetAllowSleeping(true);
    world.SetAutoClearForces(false);

    b2BodyDef groundDef;
    b2Body *ground = world.CreateBody(&groundDef);
    b2EdgeShape edge;
    edge.Set(b2Vec2(0.0f, 6.0f), b2Vec2(4.0f, 6.0f));
    ground->CreateFixture(&edge, 0.0f);
    edge.Set(b2Vec2(0.0f, 0.0f), b2Vec2(0.0f, 6.0f));
    ground->CreateFixture(&edge, 0.0f);
    edge.Set(b2Vec2(4.0f, 0.0f), b2Vec2(4.0f, 6.0f));
    ground->CreateFixture(&edge, 0.0f);

    for (int row = 0; row < 5; row++)
        for (int column = 0; column <= row; column++)
            box(world, 2.0f + (column - row * 0.5f) * 0.42f, 5.8f - (5 - row) * 0.42f, 0.2f, 0.2f, 0.0f);

    b2Body *bullet = ball(world, 0.3f, 1.0f, 0.05f);
    bullet->SetBullet(true);
    bullet->SetLinearVelocity(b2Vec2(30.0f, 5.0f));

    b2Body *a = box(world, 1.0f, 1.0f, 0.3f, 0.1f, 0.3f);
    b2Body *b = box(world, 1.8f, 1.0f, 0.3f, 0.1f, -0.2f);
    b2RevoluteJointDef revolute;
    revolute.Initialize(ground, a, b2Vec2(0.7f, 1.0f));
    world.CreateJoint(&revolute);
    b2DistanceJointDef distance;
    distance.Initialize(a, b, a->GetWorldCenter(), b->GetWorldCenter());
    distance.frequencyHz = 2.0f;
    distance.dampingRatio = 0.3f;
    world.CreateJoint(&distance);

    b2Body *c = box(world, 3.0f, 2.0f, 0.15f, 0.15f, 0.0f);
    b2Body *d = ball(world, 3.3f, 2.0f, 0.1f);
    b2WeldJointDef weld;
    weld.Initialize(c, d, b2Vec2(3.15f, 2.0f));
    world.CreateJoint(&weld);

    b2Body *e = box(world, 2.0f, 3.0f, 0.1f, 0.1f, 0.0f);
    b2PrismaticJointDef prismatic;
    prismatic.Initialize(ground, e, b2Vec2(2.0f, 3.0f), b2Vec2(1.0f, 0.2f));
    prismatic.enableLimit = true;
    prismatic.lowerTranslation = -0.5f;
    prismatic.upperTranslation = 0.8f;
    world.CreateJoint(&prismatic);

    b2Body *f = ball(world, 1.0f, 3.0f, 0.12f);
    f->SetLinearVelocity(b2Vec2(-2.0f, -1.0f));
    b2RopeJointDef rope;
    rope.bodyA = ground;
    rope.bodyB = f;
    rope.localAnchorA.Set(1.5f, 2.5f);
    rope.localAnchorB.Set(0.0f, 0.0f);
    rope.maxLength = 0.9f;
    world.CreateJoint(&rope);

    double accumulated = 0.0;
    for (int step = 0; step < 900; step++) {
        double total = accumulated + 1.0 / 60.0;
        accumulated = fmod(total, 0.004);
        while (total > 0.004) {
            world.Step((float)(1.0 * 0.004), 8, 3);
            total += -0.004;
        }
        world.ClearForces();
        if (step % 60 == 59)
            print(world, step);
    }
    return 0;
}
