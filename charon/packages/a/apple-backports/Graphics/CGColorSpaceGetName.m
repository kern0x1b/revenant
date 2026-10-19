#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <pthread.h>

const CFStringRef kCGColorSpaceGenericLab = CFSTR("kCGColorSpaceGenericLab");

static pthread_mutex_t charon_names_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableSetRef charon_names;

CFStringRef CGColorSpaceGetName(CGColorSpaceRef space)
{
    CFStringRef copy = space ? CGColorSpaceCopyName(space) : NULL;
    if (!copy)
        return NULL;
    pthread_mutex_lock(&charon_names_lock);
    if (!charon_names)
        charon_names = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    CFStringRef interned = (CFStringRef)CFSetGetValue(charon_names, copy);
    if (!interned) {
        CFSetAddValue(charon_names, copy);
        interned = copy;
    }
    pthread_mutex_unlock(&charon_names_lock);
    CFRelease(copy);
    return interned;
}
