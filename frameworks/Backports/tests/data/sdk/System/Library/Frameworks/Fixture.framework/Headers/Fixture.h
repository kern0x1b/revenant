@interface FXRoot

- (void)fx_implemented __attribute__((availability(ios, introduced=13.0)));
- (void)fx_newMethod __attribute__((availability(ios, introduced=14.0)));
- (void)fx_later __attribute__((availability(ios, introduced=15.0)));
- (void)fx_old __attribute__((availability(ios, introduced=5.0)));
- (void)fx_gone __attribute__((availability(ios, unavailable)));

@end

extern int fx_shared;
extern int fx_shared __attribute__((availability(ios, unavailable)));

__attribute__((availability(ios, unavailable))) @interface FXGone
- (void)fx_inside;
@end
