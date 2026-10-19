// The nine delegate messages, one case each, driven through the PORT'S OWN proxy with a recording
// delegate: a Catalyst build, because the proxy lives on MKMapView and MKMapView is UIKit's.
//
// The recording delegate implements all nine and records each call in order with the value that
// decides it, so the transcript is the CALLS, their ORDER and their VALUES and nothing else. The
// port's proxy is a CATEGORY on MKMapView, which merges into the host's own class -- the same
// mechanism the library's loader uses on a device -- so both the host's map view and the port's
// proxy are in this one process, and the class is the host's, not a renamed copy.
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface CharonRecorder : NSObject
@property (nonatomic, strong) NSMutableArray *calls;
- (void)record:(NSString *)call;
@end

@implementation CharonRecorder
@synthesize calls = _calls;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _calls = [NSMutableArray array];
    }
    return self;
}

- (void)record:(NSString *)call
{
    [_calls addObject:call];
    printf("  %s\n", [call UTF8String]);
    fflush(stdout);
}

// The nine, each recording the value that decides it: the CLASS of the thing handed over, so a nil
// and a wrong object cannot look the same.
- (id)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    [self record:[NSString stringWithFormat:@"rendererForOverlay -> %@", [overlay class]]];
    return (id)[NSString stringWithFormat:@"renderer-for-%@", [overlay class]];
}

- (void)mapView:(MKMapView *)mapView didAddOverlayRenderers:(NSArray *)renderers
{
    [self record:[NSString stringWithFormat:@"didAddOverlayRenderers -> %lu", (unsigned long)renderers.count]];
}

- (void)mapViewWillStartRenderingMap:(MKMapView *)mapView
{
    [self record:@"willStartRendering"];
}

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
    [self record:[NSString stringWithFormat:@"didFinishRendering -> %@", fullyRendered ? @"YES" : @"NO"]];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotation:(id<MKAnnotation>)annotation
{
    [self record:[NSString stringWithFormat:@"didSelectAnnotation -> %@",
                  annotation ? NSStringFromClass([annotation class]) : @"nil"]];
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotation:(id<MKAnnotation>)annotation
{
    [self record:[NSString stringWithFormat:@"didDeselectAnnotation -> %@",
                  annotation ? NSStringFromClass([annotation class]) : @"nil"]];
}

- (void)mapViewDidChangeVisibleRegion:(MKMapView *)mapView
{
    [self record:@"didChangeVisibleRegion"];
}

- (UIView *)mapView:(MKMapView *)mapView selectionAccessoryForAnnotation:(id<MKAnnotation>)annotation
{
    [self record:[NSString stringWithFormat:@"selectionAccessoryForAnnotation -> %@",
                  annotation ? NSStringFromClass([annotation class]) : @"nil"]];
    return [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
}

- (id<MKAnnotation>)mapView:(MKMapView *)mapView clusterAnnotationForMemberAnnotations:(NSArray<id<MKAnnotation>> *)members
{
    [self record:[NSString stringWithFormat:@"clusterAnnotationForMembers -> %lu", (unsigned long)members.count]];
    return nil;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        const char *dylib = getenv("CHARON_PORT_DYLIB");
        if (dylib) {
            dlopen(dylib, RTLD_LOCAL);
        }
        // the MUTANT: a SUBCLASS of the host's own MKMapView, allocated at run time, whose
        // -charon_askForRendererOf: hands the program the WRONG ARGUMENT -- nil -- so the delegate
        // sees nil where the real one sees the overlay's class. A category would lose to the
        // class's own method, and the port's source is byte-identical in both runs.
        if (getenv("CHARON_MUTANT") != NULL) {
            Class mutant = objc_allocateClassPair([MKMapView class], "CharonMutantMapView", 0);
            IMP wrong = imp_implementationWithBlock(^(id self_, SEL _cmd, id overlay) {
                id delegate = [self_ delegate];
                SEL asked = NSSelectorFromString(@"mapView:rendererForOverlay:");
                if ([delegate respondsToSelector:asked]) {
                    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, asked, self_, nil);
                }
                return nil;
            });
            class_addMethod(mutant, NSSelectorFromString(@"charon_askForRendererOf:"), wrong, "@@:@");
            objc_registerClassPair(mutant);
            printf("#   (a subclass of the host's own MKMapView, passing the WRONG argument)\n");
        }

        // the HOST's own MKMapView, or the mutant's subclass of it -- a `?:` cannot be a message
        // receiver, so the class is chosen first and the map view allocated from it after.
        Class mapClass = NSClassFromString(@"CharonMutantMapView") ?: [MKMapView class];
        MKMapView *mapView = [[mapClass alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        CharonRecorder *recorder = [[CharonRecorder alloc] init];
        mapView.delegate = (id<MKMapViewDelegate>)recorder;

        // the MUTANT's own method where it has one, the port's own proxy everywhere else
        SEL ask = NSSelectorFromString(@"charon_askForRendererOf:");
        CLLocationCoordinate2D line[2] = {{0.0, 0.0}, {1.0, 1.0}};
        id overlay = [MKPolyline polylineWithCoordinates:line count:2];
        printf("#   (the overlay handed over is a %s)\n", NSStringFromClass([overlay class]));
        if ([mapView respondsToSelector:ask]) {
            ((id (*)(id, SEL, id))objc_msgSend)(mapView, ask, overlay);
        }
        ((void (*)(id, SEL, NSArray *))objc_msgSend)(mapView, NSSelectorFromString(@"charon_didAddOverlayRenderers:"), @[]);
        ((void (*)(id, SEL))objc_msgSend)(mapView, NSSelectorFromString(@"charon_willStartRendering"));
        ((void (*)(id, SEL, BOOL))objc_msgSend)(mapView, NSSelectorFromString(@"charon_didFinishRenderingFully:"), YES);
        MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
        ((void (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"charon_didSelectAnnotation:"), pin);
        ((void (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"charon_didDeselectAnnotation:"), pin);
        ((void (*)(id, SEL))objc_msgSend)(mapView, NSSelectorFromString(@"charon_didChangeVisibleRegion"));
        ((id (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"charon_askForSelectionAccessoryOf:"), pin);
        ((id (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"charon_askForClusterOf:"), @[pin]);

        printf("# %d call(s)\n", (int)recorder.calls.count);
    }
    return 0;
}
