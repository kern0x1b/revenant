#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <pthread.h>

const CFStringRef kCGColorSpaceGenericLab = CFSTR("kCGColorSpaceGenericLab");

static pthread_mutex_t revenant_names_lock = PTHREAD_MUTEX_INITIALIZER;
static CFMutableSetRef revenant_names;

CFStringRef CGColorSpaceGetName(CGColorSpaceRef space)
{
    CFStringRef copy = space ? CGColorSpaceCopyName(space) : NULL;
    if (!copy)
        return NULL;
    pthread_mutex_lock(&revenant_names_lock);
    if (!revenant_names)
        revenant_names = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    CFStringRef interned = (CFStringRef)CFSetGetValue(revenant_names, copy);
    if (!interned) {
        CFSetAddValue(revenant_names, copy);
        interned = copy;
    }
    pthread_mutex_unlock(&revenant_names_lock);
    CFRelease(copy);
    return interned;
}
