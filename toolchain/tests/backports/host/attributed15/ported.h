#import <Foundation/Foundation.h>
#import <stdarg.h>

@interface NSAttributedString (RevenantPortedFormat)
- (instancetype)initRevenantHostWithFormat:(NSAttributedString *)format
                                 options:(NSAttributedStringFormattingOptions)options
                                  locale:(NSLocale *)locale, ...;
- (instancetype)initRevenantHostWithFormat:(NSAttributedString *)format
                                 options:(NSAttributedStringFormattingOptions)options
                                  locale:(NSLocale *)locale
                               arguments:(va_list)arguments;
+ (instancetype)revenantHost_localizedAttributedStringWithFormat:(NSAttributedString *)format, ...;
+ (instancetype)revenantHost_localizedAttributedStringWithFormat:(NSAttributedString *)format
                                                       options:(NSAttributedStringFormattingOptions)options, ...;
- (NSAttributedString *)revenantHost_attributedStringByInflectingString;
@end

@interface NSMutableAttributedString (RevenantPortedFormat)
- (void)revenantHost_appendLocalizedFormat:(NSAttributedString *)format, ...;
@end

@interface NSBundle (RevenantPortedBundle)
- (NSAttributedString *)revenantHost_localizedAttributedStringForKey:(NSString *)key
                                                            value:(NSString *)value
                                                            table:(NSString *)tableName;
@end

@interface NSURLSessionTask (RevenantPortedTaskDelegate)
- (id<NSURLSessionTaskDelegate>)revenantHost_delegate;
- (void)revenantHost_setDelegate:(id<NSURLSessionTaskDelegate>)delegate;
@end

@interface NSAttributedString (RevenantPortedMarkdown)
- (instancetype)initRevenantHostWithMarkdown:(NSData *)markdown
                                   options:(id)options
                                   baseURL:(NSURL *)baseURL
                                    error:(NSError **)error;
- (instancetype)initRevenantHostWithMarkdownString:(NSString *)markdownString
                                         options:(id)options
                                         baseURL:(NSURL *)baseURL
                                          error:(NSError **)error;
- (instancetype)initRevenantHostWithContentsOfMarkdownFileAtURL:(NSURL *)markdownFile
                                                     options:(id)options
                                                     baseURL:(NSURL *)baseURL
                                                       error:(NSError **)error;
@end
