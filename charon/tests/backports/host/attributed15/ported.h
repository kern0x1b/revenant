// The port's own members under the names prefix_selectors.py gave them.
//
// The tool writes these declarations itself, into the declarations header it hands back, and run.sh
// checks every selector below appears in that file, so the two cannot drift. This copy exists because
// the tool's is written from the AST and drops the variadics: calling a variadic member through a
// non-variadic prototype is not a call, it is a misread - measured, with a member that answers
// "Ann 3" when it is given "Bob 7" - so the members that are variadic in the SDK are variadic here.
#import <Foundation/Foundation.h>
#import <stdarg.h>

// NSAttributedStringLocalizedFormat15.m
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

// NSBundle+LocalizedAttributed15.m
@interface NSBundle (CharonPortedBundle)
- (NSAttributedString *)charonHost_localizedAttributedStringForKey:(NSString *)key
                                                            value:(NSString *)value
                                                            table:(NSString *)tableName;
@end

// NSURLSessionTask+Delegate15.m
@interface NSURLSessionTask (CharonPortedTaskDelegate)
- (id<NSURLSessionTaskDelegate>)charonHost_delegate;
- (void)charonHost_setDelegate:(id<NSURLSessionTaskDelegate>)delegate;
@end

// NSAttributedStringMarkdown15.m: the initialisers take the port's own options class, whose name the
// -D in renames gives it, so they are declared against NSObject and the test passes what it holds.
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
