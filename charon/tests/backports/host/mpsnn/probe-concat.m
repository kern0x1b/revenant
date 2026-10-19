#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#define P(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
static MPSImage *mk(id<MTLDevice> d, NSUInteger ch, const float *v, NSUInteger n) {
  MPSImageDescriptor *sd = [MPSImageDescriptor new];
  sd.width=1; sd.height=1; sd.featureChannels=ch; sd.numberOfImages=1;
  sd.channelFormat = MPSImageFeatureChannelFormatFloat32;
  MPSImage *i = [[MPSImage alloc] initWithDevice:d imageDescriptor:sd];
  [i writeBytes:v dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  (void)n; return i;
}
static void go(id<MTLDevice> d, id<MTLCommandQueue> q, const char *what, NSUInteger ch1, NSUInteger ch2) {
  float a[4]={1,2,3,4}, b[4]={5,6,7,8};
  MPSImage *x = mk(d, ch1, a, 4), *y = mk(d, ch2, b, 4);
  MPSNNConcatenationNode *n = [MPSNNConcatenationNode nodeWithSources:@[[MPSNNImageNode nodeWithHandle:x],
                                                                       [MPSNNImageNode nodeWithHandle:y]]];
  MPSNNGraph *g = [MPSNNGraph graphWithDevice:d resultImage:n.resultImage resultImageIsNeeded:YES];
  g.format = MPSImageFeatureChannelFormatFloat32;
  id<MTLCommandBuffer> cb = [q commandBuffer];
  MPSImage *out = [g encodeToCommandBuffer:cb sourceImages:@[x,y]];
  [cb commit]; [cb waitUntilCompleted];
  NSUInteger total = 8;
  float v[8]={0,0,0,0,0,0,0,0};
  if (out) {
    total = out.featureChannels;
    [out readBytes:v dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
  }
  P("%s -> %lux%lux%lu :", what, (unsigned long)out.width, (unsigned long)out.height, (unsigned long)out.featureChannels);
  for (NSUInteger i=0;i<total && i<8;i++) P(" %g", v[i]);
  P("\n");
}
int main(void){ @autoreleasepool {
  id<MTLDevice> d = MTLCreateSystemDefaultDevice();
  id<MTLCommandQueue> q = [d newCommandQueue];
  go(d,q,"1+1",1,1);
  go(d,q,"2+2",2,2);
  go(d,q,"4+4",4,4);
  go(d,q,"1+4",1,4);
  go(d,q,"3+1",3,1);
} return 0; }
