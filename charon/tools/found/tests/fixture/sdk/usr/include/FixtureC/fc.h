// The umbrella header of FixtureC: its own headers, and one header of another directory, which is not the module's own.
#ifndef FIXTURE_C_H
#define FIXTURE_C_H
#include <FixtureC/fc_inner.h>
#include <FixtureOther/other.h>
int fc_add(int a, int b);
#endif
