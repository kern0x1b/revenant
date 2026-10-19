#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: one SYMBOL\n");return 64;}
  const char*name=argv[1];
  printf("SYMBOL %s\n",name); fflush(stdout);
  const void*s=dlsym(RTLD_DEFAULT,name);
  if(!s){printf("  VERDICT missing\n");return 0;}
  CFTypeRef v=*(CFTypeRef*)s;
  CFTypeID t=CFGetTypeID(v);
  if(t==CFStringGetTypeID()){
    char buf[1024];
    if(!CFStringGetCString((CFStringRef)v,buf,sizeof buf,kCFStringEncodingUTF8)){printf("  VERDICT cfstring-unreadable\n");return 0;}
    printf("  TYPE cfstring\n  VALUE %s\n  BYTES ",buf);
    for(const unsigned char*b=(const unsigned char*)buf;*b;b++)printf("%02x",b);
    printf("\n"); return 0;
  }
  if(t==CFNumberGetTypeID()){
    long long n=0; CFNumberGetValue((CFNumberRef)v,kCFNumberLongLongType,&n);
    printf("  TYPE cfnumber\n  VALUE %lld\n",n); return 0;
  }
  if(t==CFBooleanGetTypeID()){printf("  TYPE cfboolean\n  VALUE %d\n",CFBooleanGetValue((CFBooleanRef)v)?1:0); return 0;}
  if(t==CFArrayGetTypeID()){printf("  TYPE cfarray\n"); return 0;}
  if(t==CFDictionaryGetTypeID()){printf("  TYPE cfdictionary\n"); return 0;}
  printf("  TYPE other\n  TYPEID %lu\n",(unsigned long)t); return 0;
}
