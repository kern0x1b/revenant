#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: portread SYMBOL\n");return 64;}
  const char*name=argv[1];
  printf("SYMBOL %s\n",name); fflush(stdout);
  const void*s=dlsym(RTLD_DEFAULT,name);
  if(!s){printf("  VERDICT port-missing\n");return 0;}
  CFTypeRef v=*(CFTypeRef*)s;
  if(CFGetTypeID(v)!=CFStringGetTypeID()){printf("  VERDICT port-not-a-string\n");return 0;}
  char buf[1024];
  if(!CFStringGetCString((CFStringRef)v,buf,sizeof buf,kCFStringEncodingUTF8)){printf("  VERDICT port-unreadable\n");return 0;}
  printf("  VALUE %s\n  BYTES ",buf);
  for(const unsigned char*b=(const unsigned char*)buf;*b;b++)printf("%02x",b);
  printf("\n");
  return 0;
}
