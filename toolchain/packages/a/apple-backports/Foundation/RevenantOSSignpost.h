#import <Foundation/Foundation.h>
#import <os/log.h>
#import <os/signpost.h>

@interface RevenantSignpostInterval : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *subsystem;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) NSTimeInterval seconds;
@property (nonatomic, assign) NSUInteger count;
@end
@interface RevenantSignpostInterval (RevenantSynthesis)
@end

@interface RevenantSignpostStore : NSObject
+ (NSArray<RevenantSignpostInterval *> *)intervals;
+ (void)takePointer:(void *)pointer forInterval:(RevenantSignpostInterval *)interval;
+ (void)recordBeginFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)recordEndFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)recordEventFor:(os_signpost_id_t)spid log:(os_log_t)log name:(const char *)name;
+ (void)reset;
@end
