#import <Foundation/Foundation.h>

static NSArray *naturallanguage_texts(void)
{
    return @[
        @"Hello, world! It's 3.14 o'clock, 1,000 e-mail $5 #tag @user http://a.b/c?d=1 😀👍 x.",
        @"Der Hund läuft schnell. Das ist gut!\nNeuer Absatz hier.\n\nZweiter Absatz.",
        @"Mr. Smith went to Washington. He said: \"Hello!\" Then left... Really?!",
        @"e.g. this i.e. that etc. and U.S.A. too", @"1.5 2,5 3:4 5/6 7-8 9_10 a_b c-d", @"café naïve résumé Ångström",
        @"Привет, мир! Как дела? Хорошо.", @"日本語のテキストです。これはテスト。", @"你好，世界。今天天气很好！", @"안녕하세요 세계. 잘 지내요?",
        @"Le renard brun rapide saute par-dessus le chien paresseux. C'est l'été!", @"El rápido zorro marrón salta. ¿Qué tal? ¡Muy bien!",
        @"one\ntwo\n\nthree", @"Then Dr. Who met Mrs. Jones on Fri. Nov. 5 at 9 a.m. She said vs. is short. Also e.g. Mt. Fuji, i.e. big.", @"Visit the U.S. Then go. It is Sept. Then Dec. Fine.", @"a😀b 👍🏽 👩🏻‍💻 🏴󠁧󠁢󠁥󠁮󠁧󠁿 #️⃣ 5️⃣ ✌️ x😀😀y 🇫🇷🇩🇪🇯🇵 word🎉", @"12:30 pm 50% x", @"a—b … c", @"", @"   ", @"x", @"👨‍👩‍👧‍👦 🇺🇸 ❤️ 1️⃣"];
}

static NSArray *naturallanguage_languages(void)
{
    return @[
        @"The quick brown fox jumps over the lazy dog and runs away.", @"Der schnelle braune Fuchs springt über den faulen Hund und läuft davon.",
        @"El rápido zorro marrón salta sobre el perro perezoso y se escapa.", @"Le renard brun rapide saute par-dessus le chien paresseux et s'enfuit.",
        @"Il veloce volpe marrone salta sopra il cane pigro e scappa via.", @"Быстрая коричневая лиса прыгает через ленивую собаку и убегает.",
        @"素早い茶色の狐が怠け者の犬を飛び越える。", @"12345 67890", @"😀😀😀", @"", @"   "];
}

static inline NSString *naturallanguage_tokens(id tokenizer, NSRange range)
{
    NSMutableString *out = [NSMutableString string];
    [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange r, NLTokenizerAttributes f, BOOL *stop) {
        [out appendFormat:@"[%lu+%lu:%lu]", (unsigned long)r.location, (unsigned long)r.length, (unsigned long)f];
    }];
    return out;
}

static inline NSString *naturallanguage_answer(id tokenizer, NSString *string)
{
    NSMutableString *out = [NSMutableString stringWithString:naturallanguage_tokens(tokenizer, NSMakeRange(0, string.length))];
    for (NSUInteger index = 0; index <= string.length + 1 && index < 90; index++) {
        NSRange r = [tokenizer tokenRangeAtIndex:index];
        [out appendFormat:@"|%lu:%@", (unsigned long)index, r.location == NSNotFound ? @"-" : NSStringFromRange(r)];
    }
    for (NSValue *window in @[[NSValue valueWithRange:NSMakeRange(2, 5)], [NSValue valueWithRange:NSMakeRange(0, string.length)]]) {
        NSRange w = window.rangeValue;
        NSMutableArray *ranges = [NSMutableArray array];
        for (NSValue *v in [tokenizer tokensForRange:w])
            [ranges addObject:NSStringFromRange(v.rangeValue)];
        [out appendFormat:@"|for %@:%@|enum:%@", NSStringFromRange(w), [ranges componentsJoinedByString:@","], naturallanguage_tokens(tokenizer, w)];
    }
    return out;
}
