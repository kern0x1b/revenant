#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "RevenantMapKit.h"

@implementation MKMapView (RevenantDelegate)

- (nullable id)revenant_askForRendererOf:(id<MKOverlay>)overlay
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:rendererForOverlay:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, overlay);
    }
    return nil;
}

- (nullable UIView *)revenant_askForSelectionAccessoryOf:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:selectionAccessoryForAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
    return nil;
}

- (nullable id)revenant_askForClusterOf:(NSArray<id<MKAnnotation>> *)memberAnnotations
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:clusterAnnotationForMemberAnnotations:");
    if ([delegate respondsToSelector:asked]) {
        return ((id (*)(id, SEL, MKMapView *, NSArray *))objc_msgSend)(delegate, asked, self, memberAnnotations);
    }
    return nil;
}

- (void)revenant_didAddOverlayRenderers:(NSArray *)renderers
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didAddOverlayRenderers:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, NSArray *))objc_msgSend)(delegate, asked, self, renderers);
    }
}

- (void)revenant_willStartRendering
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewWillStartRenderingMap:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *))objc_msgSend)(delegate, asked, self);
    }
}

- (void)revenant_didFinishRenderingFully:(BOOL)fullyRendered
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewDidFinishRenderingMap:fullyRendered:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, BOOL))objc_msgSend)(delegate, asked, self, fullyRendered);
    }
}

- (void)revenant_didChangeVisibleRegion
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapViewDidChangeVisibleRegion:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *))objc_msgSend)(delegate, asked, self);
    }
}

- (void)revenant_didSelectAnnotation:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didSelectAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
}

- (void)revenant_didDeselectAnnotation:(id<MKAnnotation>)annotation
{
    id<MKMapViewDelegate> delegate = [self delegate];
    SEL asked = NSSelectorFromString(@"mapView:didDeselectAnnotation:");
    if ([delegate respondsToSelector:asked]) {
        ((void (*)(id, SEL, MKMapView *, id))objc_msgSend)(delegate, asked, self, annotation);
    }
}

@end
