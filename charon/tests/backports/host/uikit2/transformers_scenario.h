#import <UIKit/UIKit.h>

// What the three colour transformers of iOS 14 answer, for both the host's own UIKit and the port's,
// as one string per line so the two can be compared line by line.
//
// The transformers are `NSString * const`-shaped symbols whose value is a block, so they are renamed
// like any other member of their group: the backport's three are the only ones renamed, and the test
// names each of them through the header, which is what the port's own header gives.

NSArray<NSString *> *transformers_scenario(void)
{
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    // The chromatic cases, and a grey sweep and a one-channel sweep: a grey says how the transform
    // maps a colour that is already grey, and the one-channel cases separate its three weights,
    // which is what identifies it rather than a fit to three points.
    NSMutableArray<UIColor *> *inputs = [NSMutableArray arrayWithArray:
        @[[UIColor colorWithRed:0.2 green:0.6 blue:0.9 alpha:1.0],
          [UIColor colorWithRed:1.0 green:0.3 blue:0.1 alpha:1.0],
          [UIColor colorWithRed:0.1 green:0.8 blue:0.2 alpha:1.0],
          [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.5],
          [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0],
          [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0]]];
    for (int step = 0; step <= 20; step++) {
        CGFloat x = step / 20.0;
        [inputs addObject:[UIColor colorWithWhite:x alpha:1.0]];
        [inputs addObject:[UIColor colorWithRed:x green:0 blue:0 alpha:1.0]];
        [inputs addObject:[UIColor colorWithRed:0 green:x blue:0 alpha:1.0]];
        [inputs addObject:[UIColor colorWithRed:0 green:0 blue:x alpha:1.0]];
    }
    NSArray<NSString *> *names = @[@"Grayscale", @"PreferredTint", @"MonochromeTint"];
    NSArray<UIConfigurationColorTransformer> *transformers =
        @[UIConfigurationColorTransformerGrayscale,
          UIConfigurationColorTransformerPreferredTint,
          UIConfigurationColorTransformerMonochromeTint];
    for (NSUInteger index = 0; index < transformers.count; index++) {
        for (UIColor *input in inputs) {
            CGFloat inR = 0, inG = 0, inB = 0, inA = 0;
            [input getRed:&inR green:&inG blue:&inB alpha:&inA];
            UIColor *out = transformers[index](input);
            CGFloat r = 0, g = 0, b = 0, a = 0;
            if (![out getRed:&r green:&g blue:&b alpha:&a]) {
                [out getWhite:&r alpha:&a];
                g = b = r;
            }
            [lines addObject:[NSString stringWithFormat:@"%@ in %.4f %.4f %.4f %.4f -> %.6f %.6f %.6f %.6f",
                                names[index], inR, inG, inB, inA, r, g, b, a]];
        }
    }
    return lines;
}
