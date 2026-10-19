// accessibilitymath/cases.m - the AXMathExpression classes of iOS 18.2 and AXCustomContent of 14.0,
// asked the same questions on both sides.
//
// The system builds these classes and the port builds them in
// Accessibility/CharonAXMathExpression.m and Accessibility/CharonAXCustomContent.m. The check is:
// build the same tree in both, ask both the same questions, and the two answers must be the same.
//
// It runs on the host because the host has the framework - its SDK carries AXMathExpression.h, and the
// two implementations are compiled into one program, the port's under names the system does not use, so
// neither can answer for the other. The port half links no Accessibility framework: its classes are its
// own.
//
// The cases whose label starts with "declaration." check a declaration, not the port's code, and
// run.sh counts them apart from the behaviour cases. There is one such group: the two protocol rows,
// which come from whichever header each side compiled against.
//
// A value that is an object is printed as a kind and a count rather than as its description, because a
// description carries an address and two runs of one program never agree on it. Identity is asked as its
// own case, so "the very array it was given" is a claim the file either backs or fails.
#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>

static void out(NSString *label, id value)
{
    printf("%s\t%s\n", label.UTF8String, [[value description] UTF8String]);
}

// The name of a class as the other half spells it. The port's half is compiled with -D renames, so
// NSStringFromClass answers `CharonPortAXMathExpression` there and `AXMathExpression` on the host; a
// kind case that printed the raw name would differ on every class and would be comparing the compile
// line rather than the two implementations. The prefix is the whole of the difference and it is
// removed here, once, so every kind case below is a real comparison.
static NSString *kindName(Class c)
{
    if (!c) {
        return @"(nil)";
    }
    NSString *name = NSStringFromClass(c);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:@"CharonPort".length] : name;
}

static NSString *kind(id o)
{
    return o ? kindName([o class]) : @"(nil)";
}

// The underline an attributed string carries at its first character, as the number AppKit and UIKit
// put in the attribute. A string is asked the same way, so the two spellings of a content can be
// compared: an attribute the plain spelling loses is an attribute a caller reading `label` never sees.
static NSString *const kMark = @"charon-underline";

static NSInteger underlines(id o)
{
    if (![o isKindOfClass:[NSAttributedString class]]) {
        return -1;
    }
    NSNumber *style = [(NSAttributedString *)o attribute:kMark atIndex:0 effectiveRange:NULL];
    return style ? style.integerValue : 0;
}

int main(void)
{
    @autoreleasepool {
        // ================= AXCustomContent, iOS 14.0 =================
        AXCustomContent *plain = [AXCustomContent customContentWithLabel:@"Orientation" value:@"Portrait"];
        out(@"cc.plain.label", plain.label);
        out(@"cc.plain.value", plain.value);
        out(@"cc.plain.attributedLabel.string", plain.attributedLabel.string);
        out(@"cc.plain.attributedValue.string", plain.attributedValue.string);
        out(@"cc.plain.attributedLabel.kind", kind(plain.attributedLabel));
        out(@"cc.plain.attributedValue.kind", kind(plain.attributedValue));
        // the two factories differ in which pair they are given, and both must answer all four
        NSAttributedString *al = [[NSAttributedString alloc] initWithString:@"Shutter"];
        NSAttributedString *av = [[NSAttributedString alloc] initWithString:@"1/250"];
        AXCustomContent *attr = [AXCustomContent customContentWithAttributedLabel:al attributedValue:av];
        out(@"cc.attr.label", attr.label);
        out(@"cc.attr.value", attr.value);
        out(@"cc.attr.attributedLabel.string", attr.attributedLabel.string);
        out(@"cc.attr.attributedValue.string", attr.attributedValue.string);
        // a label is the attributed string's own string, not a second copy of the text: the host
        // answers the very object, and the case asks identity so that a port which copies is caught
        out(@"cc.attr.label.is.attributedLabel.string", @(attr.label == attr.attributedLabel.string));
        out(@"cc.attr.value.is.attributedValue.string", @(attr.value == attr.attributedValue.string));
        // an attribute on the label has to survive into the plain spelling, or a caller reading
        // `label` loses the emphasis the application asked for
        NSAttributedString *marked = [[NSAttributedString alloc] initWithString:@"Orientation"
                                                                    attributes:@{kMark: @(1)}];
        AXCustomContent *markedContent = [AXCustomContent customContentWithAttributedLabel:marked attributedValue:av];
        out(@"cc.marked.label.underlines", @(underlines(markedContent.attributedLabel)));
        out(@"cc.marked.attributedLabel.underlines", @(underlines(markedContent.attributedLabel)));
        out(@"cc.marked.value.underlines", @(underlines(markedContent.attributedValue)));
        // Both factories COPY what they are handed. Measured on the host: a mutable string given to
        // either factory and mutated afterwards leaves what the content answers unchanged, so a caller
        // that reuses a buffer cannot change a content it has already handed to the system. That is a
        // rule about object identity over time and not about the text, and a port that held the
        // caller's string instead of copying it would answer differently for as long as the caller
        // kept the string alive - so the case mutates and then asks.
        NSMutableString *mutableLabel = [NSMutableString stringWithString:@"Orientation"];
        NSMutableString *mutableValue = [NSMutableString stringWithString:@"Portrait"];
        AXCustomContent *copied =
            [AXCustomContent customContentWithLabel:mutableLabel value:mutableValue];
        [mutableLabel appendString:@" and mutated"];
        [mutableValue appendString:@" and mutated"];
        out(@"cc.plain.factory.copies.label", copied.label);
        out(@"cc.plain.factory.copies.value", copied.value);
        NSMutableAttributedString *mutableLabelA = [[NSMutableAttributedString alloc] initWithString:@"Shutter"];
        NSMutableAttributedString *mutableValueA = [[NSMutableAttributedString alloc] initWithString:@"1/250"];
        AXCustomContent *copiedAttr =
            [AXCustomContent customContentWithAttributedLabel:mutableLabelA attributedValue:mutableValueA];
        [mutableLabelA.mutableString appendString:@" and mutated"];
        [mutableValueA.mutableString appendString:@" and mutated"];
        out(@"cc.attr.factory.copies.label", copiedAttr.label);
        out(@"cc.attr.factory.copies.value", copiedAttr.value);
        out(@"cc.attr.factory.copies.is.not.the.caller.s.object", @(copiedAttr.attributedLabel == mutableLabelA));

        // importance: the header's default, and the two numbers the enum gives
        out(@"cc.importance.default.number", @(AXCustomContentImportanceDefault));
        out(@"cc.importance.high.number", @(AXCustomContentImportanceHigh));
        out(@"cc.importance.fresh", @(plain.importance));
        plain.importance = AXCustomContentImportanceHigh;
        out(@"cc.importance.after.high", @(plain.importance));
        plain.importance = AXCustomContentImportanceDefault;
        out(@"cc.importance.after.default", @(plain.importance));
        // copy: equal, and sharing the attributed string rather than building a second one
        AXCustomContent *copy = [plain copy];
        out(@"cc.copy.equal", @([copy isEqual:plain]));
        out(@"cc.copy.same.attributedLabel", @(copy.attributedLabel == plain.attributedLabel));
        out(@"cc.copy.kind", kind(copy));
        // equality is by content, not identity, and the two spellings of the same content are equal
        out(@"cc.same.factories.not.equal", @([plain isEqual:[AXCustomContent customContentWithLabel:@"Orientation" value:@"Portrait"]]));
        out(@"cc.different.value.not.equal", @([plain isEqual:[AXCustomContent customContentWithLabel:@"Orientation" value:@"Landscape"]]));
        out(@"cc.other.class.not.equal", @([plain isEqual:(id)attr]));
        // Two contents naming the same thing and saying the same value, differing only in how eagerly
        // the user wants to hear it. A content the user wants spoken immediately is not interchangeable
        // with one they want on demand, so this asks the host whether the urgency is part of what makes
        // two contents the same content - and the case that holds the answer is the one below.
        AXCustomContent *urgent = [AXCustomContent customContentWithLabel:plain.label value:plain.value];
        urgent.importance = AXCustomContentImportanceHigh;
        out(@"cc.same.text.different.importance.equal", @([plain isEqual:urgent]));
        out(@"cc.same.text.different.importance.hash", @([plain hash] == [urgent hash]));
        out(@"cc.same.text.same.importance.equal",
            @([plain isEqual:[AXCustomContent customContentWithLabel:plain.label value:plain.value]]));
        // and a copy of a content the user wants spoken immediately, which is the case in which a copy
        // that dropped the number would be visible at all
        AXCustomContent *urgentCopy = [urgent copy];
        out(@"cc.copy.of.urgent.importance", @(urgentCopy.importance));
        out(@"cc.copy.of.urgent.equal", @([urgentCopy isEqual:urgent]));
        out(@"cc.copy.of.urgent.label", urgentCopy.label);
        out(@"cc.copy.of.urgent.attributedLabel.same", @(urgentCopy.attributedLabel == urgent.attributedLabel));
        // secure coding: the round trip keeps both spellings and the number
        out(@"cc.securecoding.supports", @([AXCustomContent supportsSecureCoding]));
        NSError *err = nil;
        for (int high = 0; high < 2; high++) {
            AXCustomContent *subject = [AXCustomContent customContentWithLabel:@"Orientation" value:@"Portrait"];
            if (high) {
                subject.importance = AXCustomContentImportanceHigh;
            }
            NSString *loop = high ? @"cc.coding.high." : @"cc.coding.default.";
            NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:subject requiringSecureCoding:YES error:&err];
            out([loop stringByAppendingString:@"archive.is.nil"], @(coded == nil));
            if (!coded) {
                continue;
            }
            AXCustomContent *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[AXCustomContent class] fromData:coded error:&err];
            NSString *prefix = loop;
            out([prefix stringByAppendingString:@"label"], back.label);
            out([prefix stringByAppendingString:@"value"], back.value);
            out([prefix stringByAppendingString:@"attributedLabel.string"], back.attributedLabel.string);
            out([prefix stringByAppendingString:@"attributedValue.string"], back.attributedValue.string);
            out([prefix stringByAppendingString:@"importance"], @(back.importance));
            out([prefix stringByAppendingString:@"equal"], @([back isEqual:subject]));
        }
        // a content that carries an attribute keeps it through the coder too
        NSData *markedCoded = [NSKeyedArchiver archivedDataWithRootObject:markedContent requiringSecureCoding:YES error:&err];
        AXCustomContent *markedBack = [NSKeyedUnarchiver unarchivedObjectOfClass:[AXCustomContent class] fromData:markedCoded error:&err];
        out(@"cc.coding.marked.underlines", @(underlines(markedBack.attributedLabel)));
        // and a decode that is refused for a class it does not name answers nil, not a crash
        NSData *foreign = [NSKeyedArchiver archivedDataWithRootObject:@(1) requiringSecureCoding:YES error:&err];
        out(@"cc.coding.foreign.is.nil", @([NSKeyedUnarchiver unarchivedObjectOfClass:[AXCustomContent class] fromData:foreign error:&err] == nil));

        // ================= AXMathExpression, iOS 18.2 =================
        // the base class: instantiable, an NSObject subclass, and carrying no member of its own
        AXMathExpression *base = [[AXMathExpression alloc] init];
        out(@"mx.base.kind", kind(base));
        out(@"mx.base.superclass", kindName([AXMathExpression superclass]));
        out(@"mx.base.responds.content", @([AXMathExpression instancesRespondToSelector:@selector(content)]));

        // the four leaves: a string kept and answered
        AXMathExpressionNumber *num = [[AXMathExpressionNumber alloc] initWithContent:@"42"];
        AXMathExpressionIdentifier *ident = [[AXMathExpressionIdentifier alloc] initWithContent:@"x"];
        AXMathExpressionOperator *op = [[AXMathExpressionOperator alloc] initWithContent:@"+"];
        AXMathExpressionText *txt = [[AXMathExpressionText alloc] initWithContent:@"where"];
        out(@"mx.number.content", num.content);
        out(@"mx.identifier.content", ident.content);
        out(@"mx.operator.content", op.content);
        out(@"mx.text.content", txt.content);
        out(@"mx.number.superclass", kindName([AXMathExpressionNumber superclass]));
        // every leaf is a kind of the base, which is what the class rows mean
        out(@"mx.number.is.base.kind", @([num isKindOfClass:[AXMathExpression class]]));
        out(@"mx.fenced.is.base.kind", @([[[AXMathExpressionFenced alloc] initWithExpressions:@[] openString:@"[" closeString:@"]"] isKindOfClass:[AXMathExpression class]]));
        // the empty string is a content, not a missing one
        AXMathExpressionNumber *empty = [[AXMathExpressionNumber alloc] initWithContent:@""];
        out(@"mx.number.empty.content", empty.content);
        out(@"mx.number.empty.kind", kind(empty.content));
        // equality is NSObject's own: no class here declares NSCopying, and two leaves built from the
        // same string are two objects on the host as well
        out(@"mx.number.equal.same.content", @([num isEqual:[[AXMathExpressionNumber alloc] initWithContent:@"42"]]));
        out(@"mx.number.equal.other.class", @([num isEqual:(id)ident]));

        NSArray<AXMathExpression *> *three = @[num, op, txt];

        // Fenced: the array, and the two delimiters, each kept as given
        AXMathExpressionFenced *fenced = [[AXMathExpressionFenced alloc] initWithExpressions:three
                                                                                 openString:@"["
                                                                                closeString:@"]"];
        out(@"mx.fenced.expressions.count", @(fenced.expressions.count));
        out(@"mx.fenced.expressions.is.same.array", @(fenced.expressions == three));
        out(@"mx.fenced.expressions.first.is.same", @(fenced.expressions.firstObject == num));
        out(@"mx.fenced.openString", fenced.openString);
        out(@"mx.fenced.closeString", fenced.closeString);

        // A container answers the very array it was given, and that is only visible when the array is
        // one that can change: a copy of an immutable array is the same array, so a case that passed
        // `@[a, b]` could not tell sharing from copying. The host shares (measured), and so does the
        // port, and the second case says what sharing costs - a caller that appends to the array it
        // built sees the change here, on both sides.
        NSMutableArray *mutable = [NSMutableArray arrayWithArray:@[num, op]];
        AXMathExpressionFenced *shared = [[AXMathExpressionFenced alloc] initWithExpressions:mutable
                                                                                 openString:@"("
                                                                                closeString:@")"];
        out(@"mx.fenced.mutable.is.same.array", @(shared.expressions == mutable));
        [mutable addObject:txt];
        out(@"mx.fenced.after.caller.appended.count", @(shared.expressions.count));
        out(@"mx.fenced.after.caller.appended.last.is.same", @(shared.expressions.lastObject == txt));

        // The four one-array containers. The host answers the array for three of them and nil for
        // AXMathExpressionRow and AXMathExpressionTable; the port answers the array for all four, and
        // the two that differ are the rows in expected-differences.tsv.
        AXMathExpressionRow *row = [[AXMathExpressionRow alloc] initWithExpressions:three];
        out(@"mx.row.expressions.is.nil", @(row.expressions == nil));
        out(@"mx.row.expressions.is.same.array", @(row.expressions == three));
        out(@"mx.row.expressions.count", @(row.expressions.count));
        AXMathExpressionTable *table = [[AXMathExpressionTable alloc] initWithExpressions:three];
        out(@"mx.table.expressions.is.nil", @(table.expressions == nil));
        out(@"mx.table.expressions.is.same.array", @(table.expressions == three));
        out(@"mx.table.expressions.count", @(table.expressions.count));
        AXMathExpressionTableRow *trow = [[AXMathExpressionTableRow alloc] initWithExpressions:three];
        out(@"mx.tablerow.expressions.is.nil", @(trow.expressions == nil));
        out(@"mx.tablerow.expressions.is.same.array", @(trow.expressions == three));
        out(@"mx.tablerow.expressions.count", @(trow.expressions.count));
        AXMathExpressionTableCell *tcell = [[AXMathExpressionTableCell alloc] initWithExpressions:three];
        out(@"mx.tablecell.expressions.is.nil", @(tcell.expressions == nil));
        out(@"mx.tablecell.expressions.is.same.array", @(tcell.expressions == three));
        out(@"mx.tablecell.expressions.count", @(tcell.expressions.count));
        // and with an empty array, which the host keeps for the three and drops for the two
        AXMathExpressionRow *row0 = [[AXMathExpressionRow alloc] initWithExpressions:@[]];
        out(@"mx.row.empty.is.nil", @(row0.expressions == nil));
        out(@"mx.row.empty.count", @(row0.expressions.count));
        AXMathExpressionTableCell *tcell0 = [[AXMathExpressionTableCell alloc] initWithExpressions:@[]];
        out(@"mx.tablecell.empty.is.nil", @(tcell0.expressions == nil));
        out(@"mx.tablecell.empty.count", @(tcell0.expressions.count));

        // UnderOver: three single expressions
        AXMathExpressionUnderOver *uo = [[AXMathExpressionUnderOver alloc] initWithBaseExpression:num
                                                                              underExpression:txt
                                                                                overExpression:op];
        out(@"mx.underover.base.is.same", @(uo.baseExpression == num));
        out(@"mx.underover.under.is.same", @(uo.underExpression == txt));
        out(@"mx.underover.over.is.same", @(uo.overExpression == op));

        // SubSuperscript: the header takes an array for the base and declares the property a single
        // expression, and the host answers the array. The cases below ask what kind of thing comes
        // back and how many of them, because that is the whole of the disagreement.
        AXMathExpressionSubSuperscript *ss = [[AXMathExpressionSubSuperscript alloc]
            initWithBaseExpression:@[num, op] subscriptExpressions:@[txt] superscriptExpressions:@[op]];
        out(@"mx.subsuperscript.base.kind", kind(ss.baseExpression));
        out(@"mx.subsuperscript.base.count", @([ss.baseExpression respondsToSelector:@selector(count)]
                                                   ? [(NSArray *)ss.baseExpression count] : -1));
        out(@"mx.subsuperscript.subscriptExpressions.count", @(ss.subscriptExpressions.count));
        out(@"mx.subsuperscript.superscriptExpressions.count", @(ss.superscriptExpressions.count));
        out(@"mx.subsuperscript.superscript.first.is.same", @(ss.superscriptExpressions.firstObject == op));
        AXMathExpressionSubSuperscript *ssEmpty = [[AXMathExpressionSubSuperscript alloc]
            initWithBaseExpression:@[] subscriptExpressions:@[] superscriptExpressions:@[]];
        out(@"mx.subsuperscript.empty.subscript.is.nil", @(ssEmpty.subscriptExpressions == nil));
        out(@"mx.subsuperscript.empty.superscript.is.nil", @(ssEmpty.superscriptExpressions == nil));
        out(@"mx.subsuperscript.empty.base.kind", kind(ssEmpty.baseExpression));

        // Fraction: the misspelled member is the API and is kept as Apple spells it
        AXMathExpressionFraction *frac = [[AXMathExpressionFraction alloc] initWithNumeratorExpression:num
                                                                                 denimonatorExpression:op];
        out(@"mx.fraction.numeratorExpression.is.same", @(frac.numeratorExpression == num));
        out(@"mx.fraction.denimonatorExpression.is.same", @(frac.denimonatorExpression == op));

        // Multiscript: a single base and two arrays of the sub/superscript class
        AXMathExpressionMultiscript *ms = [[AXMathExpressionMultiscript alloc] initWithBaseExpression:num
                                                                                  prescriptExpressions:@[ss]
                                                                                  postscriptExpressions:@[ssEmpty]];
        out(@"mx.multiscript.baseExpression.is.same", @(ms.baseExpression == num));
        out(@"mx.multiscript.prescriptExpressions.count", @(ms.prescriptExpressions.count));
        out(@"mx.multiscript.prescript.first.is.same", @(ms.prescriptExpressions.firstObject == ss));
        out(@"mx.multiscript.postscriptExpressions.count", @(ms.postscriptExpressions.count));
        out(@"mx.multiscript.postscript.first.is.same", @(ms.postscriptExpressions.firstObject == ssEmpty));

        // Root: the radicand is the array, the index is the single expression
        AXMathExpressionRoot *root = [[AXMathExpressionRoot alloc] initWithRadicandExpressions:three
                                                                       rootIndexExpression:num];
        out(@"mx.root.radicandExpressions.count", @(root.radicandExpressions.count));
        out(@"mx.root.radicandExpressions.is.same.array", @(root.radicandExpressions == three));
        out(@"mx.root.rootIndexExpression.is.same", @(root.rootIndexExpression == num));

        // The description, with the class and the address cut off: the two halves are the same class
        // under two names and two addresses, so what can be compared is the part after them, which is
        // the two values and the spelling the system uses for them. The importance is in no case here,
        // because the system's own description does not print it either.
        NSString *described = plain.description;
        NSRange tail = [described rangeOfString:@">: "];
        out(@"cc.description.tail", tail.location == NSNotFound ? described
                                                                : [described substringFromIndex:NSMaxRange(tail)]);
        out(@"cc.description.mentions.importance",
            @([described rangeOfString:@"importance"].location != NSNotFound));
        out(@"cc.urgent.description.mentions.importance",
            @([urgent.description rangeOfString:@"importance"].location != NSNotFound));

        // The header's promise is a promise and not a check: a caller that breaks it gets nil back and
        // not an exception, and a port that raised would differ here.
        AXMathExpressionNumber *nilContent = [[AXMathExpressionNumber alloc] initWithContent:nil];
        out(@"mx.nil.content.is.nil", @(nilContent.content == nil));
        AXMathExpressionFenced *nilFenced = [[AXMathExpressionFenced alloc] initWithExpressions:nil
                                                                                     openString:nil
                                                                                    closeString:nil];
        out(@"mx.nil.fenced.expressions.is.nil", @(nilFenced.expressions == nil));
        out(@"mx.nil.fenced.openString.is.nil", @(nilFenced.openString == nil));
        AXMathExpressionFraction *nilFrac = [[AXMathExpressionFraction alloc] initWithNumeratorExpression:nil
                                                                                    denimonatorExpression:nil];
        out(@"mx.nil.fraction.numerator.is.nil", @(nilFrac.numeratorExpression == nil));
        AXMathExpressionUnderOver *nilUO = [[AXMathExpressionUnderOver alloc] initWithBaseExpression:nil
                                                                                  underExpression:nil
                                                                                    overExpression:nil];
        out(@"mx.nil.underover.base.is.nil", @(nilUO.baseExpression == nil));
        AXMathExpressionRoot *nilRoot = [[AXMathExpressionRoot alloc] initWithRadicandExpressions:nil
                                                                          rootIndexExpression:nil];
        out(@"mx.nil.root.radicand.is.nil", @(nilRoot.radicandExpressions == nil));

        // A whole tree at once, the way an application builds one: every container that both sides can
        // walk nested in every other, and each of its own members read back. If a member answered
        // something other than what it was given, this is the case that would show it.
        //
        // The two containers left out of this chain are AXMathExpressionRow and AXMathExpressionTable,
        // and the reason is the one expected-differences.tsv declares: the host answers nil for their
        // `expressions`, so a chain through one of them has nothing to walk on the host's side and every
        // case below it would differ for that reason alone rather than for the member it is about. They
        // are built and read by their own cases above instead.
        AXMathExpressionNumber *n2 = [[AXMathExpressionNumber alloc] initWithContent:@"2"];
        AXMathExpressionFraction *half = [[AXMathExpressionFraction alloc] initWithNumeratorExpression:num
                                                                                     denimonatorExpression:n2];
        AXMathExpressionSubSuperscript *power = [[AXMathExpressionSubSuperscript alloc]
            initWithBaseExpression:@[ident] subscriptExpressions:@[txt] superscriptExpressions:@[n2]];
        AXMathExpressionUnderOver *sum = [[AXMathExpressionUnderOver alloc] initWithBaseExpression:ident
                                                                                  underExpression:txt
                                                                                    overExpression:op];
        AXMathExpressionRoot *cube = [[AXMathExpressionRoot alloc] initWithRadicandExpressions:@[half]
                                                                            rootIndexExpression:n2];
        AXMathExpressionMultiscript *multi = [[AXMathExpressionMultiscript alloc] initWithBaseExpression:sum
                                                                                      prescriptExpressions:@[power]
                                                                                      postscriptExpressions:@[power]];
        AXMathExpressionTableCell *cell = [[AXMathExpressionTableCell alloc] initWithExpressions:@[power, cube, multi]];
        AXMathExpressionTableRow *deepRow = [[AXMathExpressionTableRow alloc] initWithExpressions:@[cell]];
        AXMathExpressionFenced *everything = [[AXMathExpressionFenced alloc] initWithExpressions:@[deepRow]
                                                                                     openString:@"["
                                                                                    closeString:@"]"];
        out(@"tree.fenced.expressions.count", @(everything.expressions.count));
        out(@"tree.fenced.first.is.same", @(everything.expressions.firstObject == deepRow));
        out(@"tree.trow.expressions.count", @(deepRow.expressions.count));
        out(@"tree.trow.first.is.same", @(deepRow.expressions.firstObject == cell));
        out(@"tree.cell.expressions.count", @(cell.expressions.count));
        out(@"tree.cell.first.is.same", @(cell.expressions.firstObject == power));
        out(@"tree.cell.third.is.same", @(cell.expressions.lastObject == multi));
        // and the leaves of that tree, read back through four levels of container
        AXMathExpressionSubSuperscript *treePower = (AXMathExpressionSubSuperscript *)cell.expressions.firstObject;
        AXMathExpressionRoot *treeCube = (AXMathExpressionRoot *)cell.expressions[1];
        AXMathExpressionFraction *treeFraction = (AXMathExpressionFraction *)treeCube.radicandExpressions.firstObject;
        out(@"tree.power.base.kind", kind(treePower.baseExpression));
        out(@"tree.power.subscript.first.is.same", @(treePower.subscriptExpressions.firstObject == txt));
        out(@"tree.power.superscript.first.is.same", @(treePower.superscriptExpressions.firstObject == n2));
        out(@"tree.cube.index.is.same", @(treeCube.rootIndexExpression == n2));
        out(@"tree.fraction.numerator.is.same", @(treeFraction.numeratorExpression == num));
        out(@"tree.fraction.denimonator.is.same", @(treeFraction.denimonatorExpression == n2));
        out(@"tree.multi.base.is.same", @(multi.baseExpression == sum));
        out(@"tree.multi.prescript.first.is.same", @(multi.prescriptExpressions.firstObject == power));
        out(@"tree.underover.over.is.same", @(sum.overExpression == op));
        out(@"tree.five.levels.built", @(everything != nil && deepRow != nil && cell != nil));

        // The two protocol rows: a declaration, and not the port's code. Counted apart by run.sh.
        out(@"declaration.provider.protocol.object", kind(NSProtocolFromString(@"AXCustomContentProvider")));
        out(@"declaration.mathprovider.protocol.object", kind(NSProtocolFromString(@"AXMathExpressionProvider")));
    }
    return 0;
}
