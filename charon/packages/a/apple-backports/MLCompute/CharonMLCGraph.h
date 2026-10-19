// What the graph and its engine offer the rest of MLCompute, and what the differential asks of them.
//
// Everything here is named Charon*, so the gate weighs none of it against a release and asks the
// registry about none of it: the graph classes are MLCompute's own API and are in the registry, and the
// engine behind them is the port's own arithmetic. The measurements both are held to are in
// facts/MLCompute/Engine.md.

#pragma once

#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

// One node of a graph computed on its own: the layer, one source and one result, and the values of the
// result written into the result tensor. YES when the layer is one this path computes. This is what
// CharonMLCElementwise covers today - the activation, which is the one layer with no parameters and no
// shape of its own - and what MLCGraph and MLCInferenceGraph will call once they are written.
//
// extern "C", because this is a C entry point that crosses a library boundary - the translation unit it is
// defined in is Objective-C++, and a C++-mangled name is not something a program outside that unit can ask
// for by name. It is also what keeps the name stable whatever the engine's own language becomes.
//
// The default visibility, because the library is compiled -fvisibility=hidden and the linker cannot export
// what the compiler hid: this is the one symbol of the port that is meant to be asked for from outside, and
// the differential asks for it by name through dlopen and dlsym. Everything else in the translation unit
// stays hidden, so the classes and the engine's own symbols are not reachable that way.
#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default"))) BOOL CharonMLCElementwise(MLCLayer *layer, MLCTensor *input, MLCTensor *output);

#ifdef __cplusplus
}
#endif
