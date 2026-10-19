#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
int main(void){ @autoreleasepool {
  id<MTLDevice> d = MTLCreateSystemDefaultDevice();
  id<MTLCommandQueue> q = [d newCommandQueue];
  MPSImageDescriptor *sd = [MPSImageDescriptor new];
  sd.width=2; sd.height=2; sd.featureChannels=1; sd.numberOfImages=1;
  sd.channelFormat = MPSImageFeatureChannelFormatFloat32;
  MPSImage *a = [[MPSImage alloc] initWithDevice:d imageDescriptor:sd];
  MPSImage *b = [[MPSImage alloc] initWithDevice:d imageDescriptor:sd];
  static float in[4]={1,2,3,4}, in2[4]={10,20,30,40};
  [a writeBytes:in dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  [b writeBytes:in2 dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  MPSNNImageNode *an = [MPSNNImageNode nodeWithHandle:a];
  MPSNNImageNode *bn = [MPSNNImageNode nodeWithHandle:b];
  MPSNNAdditionNode *n = [MPSNNAdditionNode nodeWithLeftSource:an rightSource:bn];
  P("default primaryScale %g secondaryScale %g bias %g\n", n.primaryScale, n.secondaryScale, n.bias);
  n.primaryScale = 2.0f;
  P("after set primaryScale %g\n", n.primaryScale);
  MPSNNGraph *g = [MPSNNGraph graphWithDevice:d resultImage:n.resultImage resultImageIsNeeded:YES];
  g.format = MPSImageFeatureChannelFormatFloat32;
  id<MTLCommandBuffer> cb = [q commandBuffer];
  MPSImage *out = [g encodeToCommandBuffer:cb sourceImages:@[a,b]];
  [cb commit]; [cb waitUntilCompleted];
  float v[4]={0,0,0,0};
  if (out) [out readBytes:v dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  P("through the graph: %g %g %g %g\n", v[0],v[1],v[2],v[3]);
  // the same addition with no graph at all, through the node's own kernel class
  MPSImageAdd *k = [[MPSImageAdd alloc] initWithDevice:d];
  k.primaryScale = 2.0f;
  MPSImage *c = [[MPSImage alloc] initWithDevice:d imageDescriptor:sd];
  id<MTLCommandBuffer> cb2 = [q commandBuffer];
  [k encodeToCommandBuffer:cb2 primaryImage:a secondaryImage:b destinationImage:c];
  [cb2 commit]; [cb2 waitUntilCompleted];
  float w[4]={0,0,0,0};
  [c readBytes:w dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  P("through MPSImageAdd with primaryScale 2: %g %g %g %g\n", w[0],w[1],w[2],w[3]);
} return 0; }
