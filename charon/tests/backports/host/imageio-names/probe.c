#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
/* ONE SYMBOL PER PROCESS, on purpose.

   Two defects are recorded here because both cost a run to find. FIRST, dlsym on a kCGImage* name returns
   the ADDRESS OF THE VARIABLE, not the object: these are const CFStringRef globals, so the CFStringRef is
   *s. Calling CFGetTypeID on the address itself faulted with SIGBUS before this program printed anything,
   in every batch, with or without Foundation linked - which is what made it look like a dyld problem. It
   was a dereference. SECOND, one process per symbol: a batch cannot say WHICH name faulted, so the name is
   printed BEFORE the read and a fault names its own symbol instead of ending the run unexplained. */
int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: one SYMBOL\n");return 64;}
  const char*name=argv[1];
  printf("SYMBOL %s\n",name); fflush(stdout);
  const void*s=dlsym(RTLD_DEFAULT,name);
  if(!s){printf("  VERDICT missing\n");return 0;}
  /* kCGImageProperty* are const CFStringRef VARIABLES: dlsym returns the ADDRESS of the variable, so the
     object is *(CFTypeRef*)s. Reading CFGetTypeID on the address itself is what faulted every batch. */
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
