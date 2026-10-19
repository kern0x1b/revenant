#import <Foundation/Foundation.h>
#import <stdarg.h>

@interface NSAttributedString (CharonPortedFormat)
- (instancetype)initCharonHostWithFormat:(NSAttributedString *)format
                                 options:(NSAttributedStringFormattingOptions)options
                                  locale:(NSLocale *)locale, ...;
- (instancetype)initCharonHostWithFormat:(NSAttributedString *)format
                                 options:(NSAttributedStringFormattingOptions)options
                                  locale:(NSLocale *)locale
                               arguments:(va_list)arguments;
+ (instancetype)charonHost_localizedAttributedStringWithFormat:(NSAttributedString *)format, ...;
+ (instancetype)charonHost_localizedAttributedStringWithFormat:(NSAttributedString *)format
                                                       options:(NSAttributedStringFormattingOptions)options, ...;
- (NSAttributedString *)charonHost_attributedStringByInflectingString;
@end

@interface NSMutableAttributedString (CharonPortedFormat)
- (void)charonHost_appendLocalizedFormat:(NSAttributedString *)format, ...;
@end

@interface NSBundle (CharonPortedBundle)
- (NSAttributedString *)charonHost_localizedAttributedStringForKey:(NSString *)key
                                                            value:(NSString *)value
                                                            table:(NSString *)tableName;
@end

@interface NSURLSessionTask (CharonPortedTaskDelegate)
- (id<NSURLSessionTaskDelegate>)charonHost_delegate;
- (void)charonHost_setDelegate:(id<NSURLSessionTaskDelegate>)delegate;
@end

@interface NSAttributedString (CharonPortedMarkdown)
- (instancetype)initCharonHostWithMarkdown:(NSData *)markdown
                                   options:(id)options
                                   baseURL:(NSURL *)baseURL
                                    error:(NSError **)error;
- (instancetype)initCharonHostWithMarkdownString:(NSString *)markdownString
                                         options:(id)options
                                         baseURL:(NSURL *)baseURL
                                          error:(NSError **)error;
- (instancetype)initCharonHostWithContentsOfMarkdownFileAtURL:(NSURL *)markdownFile
                                                     options:(id)options
                                                     baseURL:(NSURL *)baseURL
                                                       error:(NSError **)error;
@end
