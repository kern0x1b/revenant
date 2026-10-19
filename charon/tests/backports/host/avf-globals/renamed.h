/* renamed.h - declarations for the port's own renamed definitions, for the host build of the functions
 * phase only.
 *
 * The port's CharonAVFoundationCaption18.h declares the eight AVCaptureReactionType constants and is
 * guarded out on this host, because the macOS SDK here ships AVCaptureReactions.h and declares them
 * itself (MacOSX.sdk/.../AVCaptureReactions.h:43). So when the copy of AVFoundationFunctions180.m is
 * rewritten to compare against charon_host_AVCaptureReactionType*, the names it compares against have
 * no declaration in this build and the compile stops with "use of undeclared identifier".
 *
 * These are the eight declarations it needs, and nothing else: this header is force-included into the
 * two copies of the port's sources in the functions phase and is not part of the port's own build.
 *
 * It imports Foundation itself, because a force-included header is read BEFORE the source's own
 * #import: without this NSString is not declared yet and every line below is "unknown type name".
 */
#import <Foundation/Foundation.h>

#ifndef CHARON_AVF_GLOBALS_RENAMED_H
#define CHARON_AVF_GLOBALS_RENAMED_H

extern NSString *const charon_host_AVCaptureReactionTypeThumbsUp;
extern NSString *const charon_host_AVCaptureReactionTypeThumbsDown;
extern NSString *const charon_host_AVCaptureReactionTypeBalloons;
extern NSString *const charon_host_AVCaptureReactionTypeHeart;
extern NSString *const charon_host_AVCaptureReactionTypeFireworks;
extern NSString *const charon_host_AVCaptureReactionTypeConfetti;
extern NSString *const charon_host_AVCaptureReactionTypeLasers;
extern NSString *const charon_host_AVCaptureReactionTypeRain;

#endif