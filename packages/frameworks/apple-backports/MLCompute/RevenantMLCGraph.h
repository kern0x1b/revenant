#pragma once

#import <Foundation/Foundation.h>
#import <MLCompute/MLCompute.h>

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default"))) BOOL RevenantMLCElementwise(MLCLayer *layer, MLCTensor *input, MLCTensor *output);

#ifdef __cplusplus
}
#endif
