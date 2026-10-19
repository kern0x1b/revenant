#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

@implementation MKMapView (CharonDelegate)

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
