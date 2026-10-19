#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
/* The PORT's own value, not the host's.

   This program is LINKED WITH THE PORT'S OBJECT, so dlsym(RTLD_DEFAULT, name) finds the port's symbol
   and the port's CFStringRef is what it reads. run.sh links one mutant object at a time into a private
   copy of this program, so a mutant is COMPILED, LINKED and READ - the previous harness only compiled the
   mutant and never linked or read it, so its NOT NOTICED branch could not be reached.

   Same trap as probe.c and it is the reason the value is dereferenced: these are const CFStringRef
   VARIABLES, so dlsym returns the address of the variable and the object is *(CFTypeRef*)s. */
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
