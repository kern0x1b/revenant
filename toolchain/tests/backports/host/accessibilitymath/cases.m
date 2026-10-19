#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>

static void out(NSString *label, id value)
{
    printf("%s\t%s\n", label.UTF8String, [[value description] UTF8String]);
}

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
        AXCustomContent *plain = [AXCustomContent customContentWithLabel:@"Orientation" value:@"Portrait"];
        out(@"cc.plain.label", plain.label);
        out(@"cc.plain.value", plain.value);
        out(@"cc.plain.attributedLabel.string", plain.attributedLabel.string);
        out(@"cc.plain.attributedValue.string", plain.attributedValue.string);
        out(@"cc.plain.attributedLabel.kind", kind(plain.attributedLabel));
        out(@"cc.plain.attributedValue.kind", kind(plain.attributedValue));
        NSAttributedString *al = [[NSAttributedString alloc] initWithString:@"Shutter"];
        NSAttributedString *av = [[NSAttributedString alloc] initWithString:@"1/250"];
        AXCustomContent *attr = [AXCustomContent customContentWithAttributedLabel:al attributedValue:av];
        out(@"cc.attr.label", attr.label);
        out(@"cc.attr.value", attr.value);
        out(@"cc.attr.attributedLabel.string", attr.attributedLabel.string);
        out(@"cc.attr.attributedValue.string", attr.attributedValue.string);
        out(@"cc.attr.label.is.attributedLabel.string", @(attr.label == attr.attributedLabel.string));
        out(@"cc.attr.value.is.attributedValue.string", @(attr.value == attr.attributedValue.string));
        NSAttributedString *marked = [[NSAttributedString alloc] initWithString:@"Orientation"
                                                                    attributes:@{kMark: @(1)}];
        AXCustomContent *markedContent = [AXCustomContent customContentWithAttributedLabel:marked attributedValue:av];
        out(@"cc.marked.label.underlines", @(underlines(markedContent.attributedLabel)));
        out(@"cc.marked.attributedLabel.underlines", @(underlines(markedContent.attributedLabel)));
        out(@"cc.marked.value.underlines", @(underlines(markedContent.attributedValue)));
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

        out(@"cc.importance.default.number", @(AXCustomContentImportanceDefault));
        out(@"cc.importance.high.number", @(AXCustomContentImportanceHigh));
        out(@"cc.importance.fresh", @(plain.importance));
        plain.importance = AXCustomContentImportanceHigh;
        out(@"cc.importance.after.high", @(plain.importance));
        plain.importance = AXCustomContentImportanceDefault;
        out(@"cc.importance.after.default", @(plain.importance));
        AXCustomContent *copy = [plain copy];
        out(@"cc.copy.equal", @([copy isEqual:plain]));
        out(@"cc.copy.same.attributedLabel", @(copy.attributedLabel == plain.attributedLabel));
        out(@"cc.copy.kind", kind(copy));
        out(@"cc.same.factories.not.equal", @([plain isEqual:[AXCustomContent customContentWithLabel:@"Orientation" value:@"Portrait"]]));
        out(@"cc.different.value.not.equal", @([plain isEqual:[AXCustomContent customContentWithLabel:@"Orientation" value:@"Landscape"]]));
        out(@"cc.other.class.not.equal", @([plain isEqual:(id)attr]));
        AXCustomContent *urgent = [AXCustomContent customContentWithLabel:plain.label value:plain.value];
        urgent.importance = AXCustomContentImportanceHigh;
        out(@"cc.same.text.different.importance.equal", @([plain isEqual:urgent]));
        out(@"cc.same.text.different.importance.hash", @([plain hash] == [urgent hash]));
        out(@"cc.same.text.same.importance.equal",
            @([plain isEqual:[AXCustomContent customContentWithLabel:plain.label value:plain.value]]));
        AXCustomContent *urgentCopy = [urgent copy];
        out(@"cc.copy.of.urgent.importance", @(urgentCopy.importance));
        out(@"cc.copy.of.urgent.equal", @([urgentCopy isEqual:urgent]));
        out(@"cc.copy.of.urgent.label", urgentCopy.label);
        out(@"cc.copy.of.urgent.attributedLabel.same", @(urgentCopy.attributedLabel == urgent.attributedLabel));
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
        NSData *markedCoded = [NSKeyedArchiver archivedDataWithRootObject:markedContent requiringSecureCoding:YES error:&err];
        AXCustomContent *markedBack = [NSKeyedUnarchiver unarchivedObjectOfClass:[AXCustomContent class] fromData:markedCoded error:&err];
        out(@"cc.coding.marked.underlines", @(underlines(markedBack.attributedLabel)));
        NSData *foreign = [NSKeyedArchiver archivedDataWithRootObject:@(1) requiringSecureCoding:YES error:&err];
        out(@"cc.coding.foreign.is.nil", @([NSKeyedUnarchiver unarchivedObjectOfClass:[AXCustomContent class] fromData:foreign error:&err] == nil));

        AXMathExpression *base = [[AXMathExpression alloc] init];
        out(@"mx.base.kind", kind(base));
        out(@"mx.base.superclass", kindName([AXMathExpression superclass]));
        out(@"mx.base.responds.content", @([AXMathExpression instancesRespondToSelector:@selector(content)]));

        AXMathExpressionNumber *num = [[AXMathExpressionNumber alloc] initWithContent:@"42"];
        AXMathExpressionIdentifier *ident = [[AXMathExpressionIdentifier alloc] initWithContent:@"x"];
        AXMathExpressionOperator *op = [[AXMathExpressionOperator alloc] initWithContent:@"+"];
        AXMathExpressionText *txt = [[AXMathExpressionText alloc] initWithContent:@"where"];
        out(@"mx.number.content", num.content);
        out(@"mx.identifier.content", ident.content);
        out(@"mx.operator.content", op.content);
        out(@"mx.text.content", txt.content);
        out(@"mx.number.superclass", kindName([AXMathExpressionNumber superclass]));
        out(@"mx.number.is.base.kind", @([num isKindOfClass:[AXMathExpression class]]));
        out(@"mx.fenced.is.base.kind", @([[[AXMathExpressionFenced alloc] initWithExpressions:@[] openString:@"[" closeString:@"]"] isKindOfClass:[AXMathExpression class]]));
        AXMathExpressionNumber *empty = [[AXMathExpressionNumber alloc] initWithContent:@""];
        out(@"mx.number.empty.content", empty.content);
        out(@"mx.number.empty.kind", kind(empty.content));
        out(@"mx.number.equal.same.content", @([num isEqual:[[AXMathExpressionNumber alloc] initWithContent:@"42"]]));
        out(@"mx.number.equal.other.class", @([num isEqual:(id)ident]));

        NSArray<AXMathExpression *> *three = @[num, op, txt];

        AXMathExpressionFenced *fenced = [[AXMathExpressionFenced alloc] initWithExpressions:three
                                                                                 openString:@"["
                                                                                closeString:@"]"];
        out(@"mx.fenced.expressions.count", @(fenced.expressions.count));
        out(@"mx.fenced.expressions.is.same.array", @(fenced.expressions == three));
        out(@"mx.fenced.expressions.first.is.same", @(fenced.expressions.firstObject == num));
        out(@"mx.fenced.openString", fenced.openString);
        out(@"mx.fenced.closeString", fenced.closeString);

        NSMutableArray *mutable = [NSMutableArray arrayWithArray:@[num, op]];
        AXMathExpressionFenced *shared = [[AXMathExpressionFenced alloc] initWithExpressions:mutable
                                                                                 openString:@"("
                                                                                closeString:@")"];
        out(@"mx.fenced.mutable.is.same.array", @(shared.expressions == mutable));
        [mutable addObject:txt];
        out(@"mx.fenced.after.caller.appended.count", @(shared.expressions.count));
        out(@"mx.fenced.after.caller.appended.last.is.same", @(shared.expressions.lastObject == txt));

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
        AXMathExpressionRow *row0 = [[AXMathExpressionRow alloc] initWithExpressions:@[]];
        out(@"mx.row.empty.is.nil", @(row0.expressions == nil));
        out(@"mx.row.empty.count", @(row0.expressions.count));
        AXMathExpressionTableCell *tcell0 = [[AXMathExpressionTableCell alloc] initWithExpressions:@[]];
        out(@"mx.tablecell.empty.is.nil", @(tcell0.expressions == nil));
        out(@"mx.tablecell.empty.count", @(tcell0.expressions.count));

        AXMathExpressionUnderOver *uo = [[AXMathExpressionUnderOver alloc] initWithBaseExpression:num
                                                                              underExpression:txt
                                                                                overExpression:op];
        out(@"mx.underover.base.is.same", @(uo.baseExpression == num));
        out(@"mx.underover.under.is.same", @(uo.underExpression == txt));
        out(@"mx.underover.over.is.same", @(uo.overExpression == op));

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

        AXMathExpressionFraction *frac = [[AXMathExpressionFraction alloc] initWithNumeratorExpression:num
                                                                                 denimonatorExpression:op];
        out(@"mx.fraction.numeratorExpression.is.same", @(frac.numeratorExpression == num));
        out(@"mx.fraction.denimonatorExpression.is.same", @(frac.denimonatorExpression == op));

        AXMathExpressionMultiscript *ms = [[AXMathExpressionMultiscript alloc] initWithBaseExpression:num
                                                                                  prescriptExpressions:@[ss]
                                                                                  postscriptExpressions:@[ssEmpty]];
        out(@"mx.multiscript.baseExpression.is.same", @(ms.baseExpression == num));
        out(@"mx.multiscript.prescriptExpressions.count", @(ms.prescriptExpressions.count));
        out(@"mx.multiscript.prescript.first.is.same", @(ms.prescriptExpressions.firstObject == ss));
        out(@"mx.multiscript.postscriptExpressions.count", @(ms.postscriptExpressions.count));
        out(@"mx.multiscript.postscript.first.is.same", @(ms.postscriptExpressions.firstObject == ssEmpty));

        AXMathExpressionRoot *root = [[AXMathExpressionRoot alloc] initWithRadicandExpressions:three
                                                                       rootIndexExpression:num];
        out(@"mx.root.radicandExpressions.count", @(root.radicandExpressions.count));
        out(@"mx.root.radicandExpressions.is.same.array", @(root.radicandExpressions == three));
        out(@"mx.root.rootIndexExpression.is.same", @(root.rootIndexExpression == num));

        NSString *described = plain.description;
        NSRange tail = [described rangeOfString:@">: "];
        out(@"cc.description.tail", tail.location == NSNotFound ? described
                                                                : [described substringFromIndex:NSMaxRange(tail)]);
        out(@"cc.description.mentions.importance",
            @([described rangeOfString:@"importance"].location != NSNotFound));
        out(@"cc.urgent.description.mentions.importance",
            @([urgent.description rangeOfString:@"importance"].location != NSNotFound));

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

        out(@"declaration.provider.protocol.object", kind(NSProtocolFromString(@"AXCustomContentProvider")));
        out(@"declaration.mathprovider.protocol.object", kind(NSProtocolFromString(@"AXMathExpressionProvider")));
    }
    return 0;
}
