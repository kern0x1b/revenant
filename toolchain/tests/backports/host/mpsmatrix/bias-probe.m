#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
static id<MTLDevice> gDevice;
typedef struct { id object; void *source; size_t bytes; } Source;
static Source gSources[64]; static NSUInteger gSourceCount;
static void remember(id o, void *s, size_t b){ gSources[gSourceCount].object=o; gSources[gSourceCount].source=s; gSources[gSourceCount].bytes=b; gSourceCount++; }
static void pull(void){ for (NSUInteger i=0;i<gSourceCount;i++){ id object = gSources[i].object; id<MTLBuffer> buffer = [object data]; memcpy(gSources[i].source, [buffer contents], gSources[i].bytes); } }
static MPSMatrix *mx(const void *v, NSUInteger r, NSUInteger c, MPSDataType t){
    size_t es=MPSSizeofMPSDataType(t);
    id<MTLBuffer> b=[gDevice newBufferWithBytes:v length:r*c*es options:MTLResourceStorageModeShared];
    MPSMatrixDescriptor *d=[MPSMatrixDescriptor matrixDescriptorWithRows:r columns:c matrices:1 rowBytes:c*es matrixBytes:r*c*es dataType:t];
    MPSMatrix *m=[[MPSMatrix alloc] initWithBuffer:b descriptor:d]; remember(m,(void*)v,r*c*es); return m;
}
static MPSVector *vx(const void *v, NSUInteger n, MPSDataType t){
    size_t es=MPSSizeofMPSDataType(t);
    id<MTLBuffer> b=[gDevice newBufferWithBytes:v length:n*es options:MTLResourceStorageModeShared];
    MPSVectorDescriptor *d=[MPSVectorDescriptor vectorDescriptorWithLength:n vectors:1 vectorBytes:n*es dataType:t];
    MPSVector *x=[[MPSVector alloc] initWithBuffer:b descriptor:d]; remember(x,(void*)v,n*es); return x;
}
static void run(void (^e)(id<MTLCommandBuffer>)){ id<MTLCommandQueue> q=[gDevice newCommandQueue]; id<MTLCommandBuffer> cb=[q commandBufferWithUnretainedReferences]; e(cb); [cb commit]; [cb waitUntilCompleted]; }
static float src[3][4]={{-2,-0.5f,0,0.5f},{1,2,3,4},{-8,8,0.1f,2}};
static float bias[4]={0.25f,-0.25f,0.5f,-0.5f};
static float inc[3][4], gd[3][4], gb[4];
static MPSCNNNeuronType types[] = {
    MPSCNNNeuronTypeNone, MPSCNNNeuronTypeReLU, MPSCNNNeuronTypeLinear, MPSCNNNeuronTypeSigmoid,
    MPSCNNNeuronTypeHardSigmoid, MPSCNNNeuronTypeTanH, MPSCNNNeuronTypeAbsolute, MPSCNNNeuronTypeSoftPlus,
    MPSCNNNeuronTypeSoftSign, MPSCNNNeuronTypeELU, MPSCNNNeuronTypeReLUN, MPSCNNNeuronTypePower,
    MPSCNNNeuronTypeExponential, MPSCNNNeuronTypeLogarithm, MPSCNNNeuronTypeGeLU
};
static float control[3][4] = {{1,2,3,4},{0.5f,0.25f,0.125f,0.0625f},{2,2,2,2}};
int main(void){ @autoreleasepool {
    gDevice=MTLCreateSystemDefaultDevice();
    for (int which = 0; which < 3; which++) {
      for (int t = 0; t < 15; t++) {
        for (int i=0;i<3;i++) for (int j=0;j<4;j++) inc[i][j]=0;
        if (which==0) inc[0][0]=1;
        else if (which==1) { inc[0][0]=1; inc[1][1]=1; inc[2][2]=1; }
        else { memcpy(inc,control,sizeof(inc)); }
        for (int i=0;i<3;i++) for (int j=0;j<4;j++) gd[i][j]=0;
        for (int j=0;j<4;j++) gb[j]=0;
        run(^(id<MTLCommandBuffer> cb){
            MPSMatrix *in=mx(&src[0][0],3,4,MPSDataTypeFloat32);
            MPSMatrix *g=mx(&inc[0][0],3,4,MPSDataTypeFloat32);
            MPSMatrix *o=mx(&gd[0][0],3,4,MPSDataTypeFloat32);
            MPSVector *bv=vx(&bias[0],4,MPSDataTypeFloat32);
            MPSVector *gbv=vx(&gb[0],4,MPSDataTypeFloat32);
            MPSMatrixNeuronGradient *k=[[MPSMatrixNeuronGradient alloc] initWithDevice:gDevice];
            [k setNeuronType:types[t] parameterA:1.5f parameterB:0.75f parameterC:2.5f];
            k.alpha=0.5;
            [k encodeToCommandBuffer:cb gradientMatrix:g inputMatrix:in biasVector:bv resultGradientForDataMatrix:o resultGradientForBiasVector:gbv];
        });
        pull();
        printf("incoming=%d type=%2d bias[", which, t);
        for (int j=0;j<4;j++) printf("%.9g%s", gb[j], j<3?", ":"");
        printf("]  data[");
        for (int i=0;i<3;i++) for (int j=0;j<4;j++) printf("%.9g%s", gd[i][j], (i<2||j<3)?",":"");
        printf("]\n");
        gSourceCount=0;
      }
    }
} return 0; }
