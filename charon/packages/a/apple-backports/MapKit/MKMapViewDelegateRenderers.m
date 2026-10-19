// The nine delegate messages the release's own MKMapView has no way to ask for, and the port's own
// protocol and proxy that ask for them anyway.
//
// Measured with apple.objc.inventory on the armv7 cache of 6.1.3: the release's own
// MKMapViewDelegate has the iOS 6 set and NONE of these nine, and the release's own map view asks for
// none of them. So:
//
//   * the protocol is the PORT'S OWN, declared in CharonMapKit.h behind CHARON_HOST_PROBE, because
//     the host's MapKit declares one of the same name and the two cannot both be live;
//   * the PROXY in MKMapView+Renderers.m is what sends them: the ones the port's own renderer tree can
//     make happen are sent from the port's own map view code, and the five that need the MAP VIEW to
//     ask -- the renderer, the selection accessory, the cluster and the grouping -- are asked by the
//     proxy calling the program's own delegate, because on this release the map view will not.
//
// Every one of the nine has a case in the differential, tests/backports/host/mapkit-delegate, which
// drives the port's own proxy with a delegate that records every call in order and checks the
// transcript: the five asked calls carry the program the MAP VIEW and the argument the header's own
// signature names, and the four sent calls carry the template or the annotation the port's own code
// is acting on.
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

@implementation MKMapView (CharonDelegate)

// The five the map view cannot ask for, asked of the program's own delegate by the port's proxy.
// Each is one message, and each is asked only where the port's own code has something to ask about,
// so a program is never called with a question the port cannot answer.
- (nullable id)charon_askForRendererOf:(id<MKOverlay>)overlay
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:rendererForOverlay:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, overlay);
    }
    return nil;
}

- (nullable UIView *)charon_askForSelectionAccessoryOf:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:selectionAccessoryForAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
    return nil;
}

- (nullable id)charon_askForClusterOf:(NSArray<id<MKAnnotation>> *)memberAnnotations
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:clusterAnnotationForMemberAnnotations:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, NSArray *))objc_msgSend)(delegate, asked, self, memberAnnotations);
    }
    return nil;
}

- (void)charon_didAddOverlayRenderers:(NSArray *)renderers
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didAddOverlayRenderers:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, NSArray *))objc_msgSend)(delegate, asked, self, renderers);
    }
}

- (void)charon_willStartRendering
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewWillStartRenderingMap:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *))objc_msgSend)(delegate, asked, self);
    }
}

- (void)charon_didFinishRenderingFully:(BOOL)fullyRendered
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewDidFinishRenderingMap:fullyRendered:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, BOOL))objc_msgSend)(delegate, asked, self, fullyRendered);
    }
}

- (void)charon_didChangeVisibleRegion
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewDidChangeVisibleRegion:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *))objc_msgSend)(delegate, asked, self);
    }
}

- (void)charon_didSelectAnnotation:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didSelectAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
}

- (void)charon_didDeselectAnnotation:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didDeselectAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
}

@end
