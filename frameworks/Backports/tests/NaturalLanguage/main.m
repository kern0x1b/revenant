#import <Foundation/Foundation.h>
#import <NaturalLanguage/NaturalLanguage.h>

static NSString *describeLanguage(NSString *language)
{
    return language ? language : @"nil";
}

static void printTokens(NLTokenUnit unit, NSString *text)
{
    NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:unit];
    tokenizer.string = text;
    NSMutableArray *parts = [NSMutableArray array];
    [tokenizer enumerateTokensInRange:NSMakeRange(0, text.length) usingBlock:^(NSRange range, NLTokenizerAttributes flags, BOOL *stop) {
        [parts addObject:[NSString stringWithFormat:@"%lu+%lu=%@", (unsigned long)range.location, (unsigned long)range.length, [text substringWithRange:range]]];
    }];
    printf("tokens %ld %s -> %s\n", (long)unit, text.UTF8String, [[parts componentsJoinedByString:@" | "] UTF8String]);
}

int main(void)
{
    NSArray<NSString *> *samples = @[
        @"The quick brown fox jumps over the lazy dog.",
        @"Der schnelle braune Fuchs springt über den faulen Hund.",
        @"Le renard brun rapide saute par-dessus le chien paresseux.",
        @"El rápido zorro marrón salta sobre el perro perezoso.",
        @"Быстрая коричневая лиса прыгает через ленивую собаку.",
        @"敏捷的棕色狐狸跳过了懒狗。",
        @"素早い茶色のキツネが怠け者の犬を飛び越える。",
        @"",
        @"12345 !!!",
    ];
    for (NSString *sample in samples) {
        NLLanguage language = [NLLanguageRecognizer dominantLanguageForString:sample];
        printf("dominant %s -> %s\n", sample.UTF8String, describeLanguage(language).UTF8String);
    }
    NLLanguageRecognizer *recognizer = [[NLLanguageRecognizer alloc] init];
    [recognizer processString:@"Der schnelle braune Fuchs springt über den faulen Hund. The quick brown fox jumps over the lazy dog."];
    printf("processed dominant -> %s\n", describeLanguage(recognizer.dominantLanguage).UTF8String);
    printf("constants %s %s %s\n", NLLanguageEnglish.UTF8String, NLLanguageGerman.UTF8String, NLLanguageRussian.UTF8String);
    NSString *text = @"Hello, world! It's 3.5 o'clock. Ok?";
    printTokens(NLTokenUnitWord, text);
    printTokens(NLTokenUnitSentence, text);
    printTokens(NLTokenUnitParagraph, @"One line.\nTwo lines.");
    printTokens(NLTokenUnitWord, @"Привет, мир! 你好世界");
    return 0;
}
