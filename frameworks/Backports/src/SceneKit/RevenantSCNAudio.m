#import "RevenantSCNAudio.h"
#include <math.h>

RevenantSCNAudioMix RevenantSCNAudioMixFor(SCNMatrix4 listenerInverse, SCNVector3 position, float sourceVolume)
{
    float x = position.x * listenerInverse.m11 + position.y * listenerInverse.m21 + position.z * listenerInverse.m31 + listenerInverse.m41;
    float y = position.x * listenerInverse.m12 + position.y * listenerInverse.m22 + position.z * listenerInverse.m32 + listenerInverse.m42;
    float z = position.x * listenerInverse.m13 + position.y * listenerInverse.m23 + position.z * listenerInverse.m33 + listenerInverse.m43;
    float distance = sqrtf(x * x + y * y + z * z);
    RevenantSCNAudioMix mix;
    mix.pan = distance > 0 ? fmaxf(-1, fminf(1, x / distance)) : 0;
    mix.volume = sourceVolume / fmaxf(1, distance);
    return mix;
}
