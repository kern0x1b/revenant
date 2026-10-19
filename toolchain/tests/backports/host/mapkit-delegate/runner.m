#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>

@interface RevenantRecorder : NSObject
@property (nonatomic, strong) NSMutableArray *calls;
- (void)record:(NSString *)call;
@end

@implementation RevenantRecorder
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
        const char *dylib = getenv("REVENANT_PORT_DYLIB");
        if (dylib) {
            dlopen(dylib, RTLD_LOCAL);
        }
        if (getenv("REVENANT_MUTANT") != NULL) {
            Class mutant = objc_allocateClassPair([MKMapView class], "RevenantMutantMapView", 0);
            IMP wrong = imp_implementationWithBlock(^(id self_, SEL _cmd, id overlay) {
                id delegate = [self_ delegate];
                SEL asked = NSSelectorFromString(@"mapView:rendererForOverlay:");
                if ([delegate respondsToSelector:asked]) {
                    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, asked, self_, nil);
                }
                return nil;
            });
            class_addMethod(mutant, NSSelectorFromString(@"revenant_askForRendererOf:"), wrong, "@@:@");
            objc_registerClassPair(mutant);
            printf("#   (a subclass of the host's own MKMapView, passing the WRONG argument)\n");
        }

        Class mapClass = NSClassFromString(@"RevenantMutantMapView") ?: [MKMapView class];
        MKMapView *mapView = [[mapClass alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        RevenantRecorder *recorder = [[RevenantRecorder alloc] init];
        mapView.delegate = (id<MKMapViewDelegate>)recorder;

        SEL ask = NSSelectorFromString(@"revenant_askForRendererOf:");
        CLLocationCoordinate2D line[2] = {{0.0, 0.0}, {1.0, 1.0}};
        id overlay = [MKPolyline polylineWithCoordinates:line count:2];
        printf("#   (the overlay handed over is a %s)\n", NSStringFromClass([overlay class]));
        if ([mapView respondsToSelector:ask]) {
            ((id (*)(id, SEL, id))objc_msgSend)(mapView, ask, overlay);
        }
        ((void (*)(id, SEL, NSArray *))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_didAddOverlayRenderers:"), @[]);
        ((void (*)(id, SEL))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_willStartRendering"));
        ((void (*)(id, SEL, BOOL))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_didFinishRenderingFully:"), YES);
        MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
        ((void (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_didSelectAnnotation:"), pin);
        ((void (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_didDeselectAnnotation:"), pin);
        ((void (*)(id, SEL))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_didChangeVisibleRegion"));
        ((id (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_askForSelectionAccessoryOf:"), pin);
        ((id (*)(id, SEL, id))objc_msgSend)(mapView, NSSelectorFromString(@"revenant_askForClusterOf:"), @[pin]);

        printf("# %d call(s)\n", (int)recorder.calls.count);
    }
    return 0;
}
