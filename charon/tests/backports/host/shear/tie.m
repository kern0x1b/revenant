// **Both axes, the same mapped centre.** At scale one and slope zero the horizontal's centre is `along -
// translate` and the vertical's is `along + translate`, so horizontal translate `-t` and vertical translate
// `+t` ask for the SAME centre on both axes. If the two axes then agree, one rounding rule serves both; if they
// part company at a position and agree everywhere else, the part is in the position and not in the rounding.
//
// A ramp source along the axis, a zero backColor, and both axes' answers side by side for every translate that
// lands on a whole phase, on half a phase, and between.
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
int main(void){@autoreleasepool{
  ResamplingFilter f=vImageNewResamplingFilter(1.0f,kvImageNoFlags);
  Pixel_ARGB_16S back={0};
  int16_t ramp[9]; for(int r=0;r<9;r++) ramp[r]=(int16_t)(1000*(r+1));
  double ts[]={0.0, 1.0/64.0, 2.0/64.0, 0.5/64.0, 1.5/64.0, 2.5/64.0, 63.5/64.0, -0.5/64.0, -1.5/64.0};
  printf("  centre at sample 0, and the two axes asked for it the same way\n");
  for(unsigned t=0;t<9;t++){
    double tr=ts[t];
    vImage_Buffer h={0},v={0};
    h.width=9;h.height=1;h.rowBytes=72;h.data=calloc(1,72);
    v.width=1;v.height=9;v.rowBytes=8;v.data=calloc(1,72);
    for(int c=0;c<9;c++) for(int k=0;k<4;k++){ ((int16_t*)h.data)[c*4+k]=ramp[c]; ((int16_t*)v.data)[c*4+k]=ramp[c]; }
    // horizontal translate -tr  <->  vertical translate +tr  : both centre on `tr` at sample 0
    vImageHorizontalShear_ARGB16S(&h,&h,0,0,(float)(-tr),0.0f,f,back,kvImageBackgroundColorFill);
    vImageVerticalShear_ARGB16S(&v,&v,0,0,(float)tr,0.0f,f,back,kvImageBackgroundColorFill);
    printf("  t = %-14.9g centre %-14.9g\n",tr,tr);
    printf("        horizontal (-t):"); for(int c=0;c<9;c++) printf(" %6d",(int)((int16_t*)h.data)[c*4]); printf("\n");
    printf("        vertical   (+t):"); for(int c=0;c<9;c++) printf(" %6d",(int)((int16_t*)v.data)[c*4]); printf("\n");
    free(h.data);free(v.data);
  }
  vImageDestroyResamplingFilter(f);
} return 0;}
