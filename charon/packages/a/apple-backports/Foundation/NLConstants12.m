#import <Foundation/Foundation.h>

// NaturalLanguage's 12.0 band, the 38 constants of SDK 26.2 the port did not carry: tag schemes (NLTagSchemeLanguage, NLTagSchemeLemma, NLTagSchemeLexicalClass, NLTagSchemeNameType, NLTagSchemeNameTypeOrLexicalClass, NLTagSchemeScript, NLTagSchemeTokenType); tags (NLTagAdjective, NLTagAdverb, NLTagClassifier, NLTagCloseParenthesis) and 27 more.
//
// Every value is the host's own. These names are `NSString * const` in every SDK header --
// NLTagScheme.h, NLScript.h, NLLanguage.h declare the name, the typedef and the release it arrived in
// and no value -- so a value read out of a header would be an invention. Each one is a data symbol in
// NaturalLanguage.framework, and tests/backports/host/naturaltags reads all 71 of them out of the
// host's own framework with one dlsym each, writes the table this file is transcribed from, and re-runs
// against that table on every run (142 checks, 0 different). That is also where the two surprising ones
// come from: NLTagOtherPunctuation is the string NLTagPunctuation is, and NLTagOtherWhitespace is the
// string NLTagWhitespace is, so those two pairs of names are two spellings of one tag and the port
// carries the system's own values rather than the distinct ones their names suggest.
//
// One release per object file: every constant here arrived in iOS 12.0 and none of them is a member of
// anything this release carries, which is what release-split reads to decide where the object belongs.
// The constants are NSString * const, as the SDK's own headers declare them, so each carries its
// initializer at its definition rather than being filled in by a constructor: a `const` object cannot be
// assigned after its definition.

NSString *const NLTagAdjective = @"Adjective";
NSString *const NLTagAdverb = @"Adverb";
NSString *const NLTagClassifier = @"Classifier";
NSString *const NLTagCloseParenthesis = @"CloseParenthesis";
NSString *const NLTagCloseQuote = @"CloseQuote";
NSString *const NLTagConjunction = @"Conjunction";
NSString *const NLTagDash = @"Dash";
NSString *const NLTagDeterminer = @"Determiner";
NSString *const NLTagIdiom = @"Idiom";
NSString *const NLTagInterjection = @"Interjection";
NSString *const NLTagNoun = @"Noun";
NSString *const NLTagNumber = @"Number";
NSString *const NLTagOpenParenthesis = @"OpenParenthesis";
NSString *const NLTagOpenQuote = @"OpenQuote";
NSString *const NLTagOrganizationName = @"OrganizationName";
NSString *const NLTagOther = @"Other";
NSString *const NLTagOtherPunctuation = @"Punctuation";
NSString *const NLTagOtherWhitespace = @"Whitespace";
NSString *const NLTagOtherWord = @"OtherWord";
NSString *const NLTagParagraphBreak = @"ParagraphBreak";
NSString *const NLTagParticle = @"Particle";
NSString *const NLTagPersonalName = @"PersonalName";
NSString *const NLTagPlaceName = @"PlaceName";
NSString *const NLTagPreposition = @"Preposition";
NSString *const NLTagPronoun = @"Pronoun";
NSString *const NLTagPunctuation = @"Punctuation";
NSString *const NLTagSchemeLanguage = @"Language";
NSString *const NLTagSchemeLemma = @"Lemma";
NSString *const NLTagSchemeLexicalClass = @"LexicalClass";
NSString *const NLTagSchemeNameType = @"NameType";
NSString *const NLTagSchemeNameTypeOrLexicalClass = @"NameTypeOrLexicalClass";
NSString *const NLTagSchemeScript = @"Script";
NSString *const NLTagSchemeTokenType = @"TokenType";
NSString *const NLTagSentenceTerminator = @"SentenceTerminator";
NSString *const NLTagVerb = @"Verb";
NSString *const NLTagWhitespace = @"Whitespace";
NSString *const NLTagWord = @"Word";
NSString *const NLTagWordJoiner = @"WordJoiner";
