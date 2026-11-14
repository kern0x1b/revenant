#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* The range of the guest images and the metadata arena (see common-includes.h): a translated Swift runtime imports them. */
extern unsigned long xl_guest_image_low, xl_guest_image_high, xl_guest_arena_low, xl_guest_arena_high;
