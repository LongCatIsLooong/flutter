// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FlutterTextInputClientView.h"
#import "flutter/lib/ui/input/text_input_model.h"
#import "flutter/shell/platform/darwin/ios/ios_text_input.h"
#import "flutter/txt/src/txt/paragraph.h"
#import "third_party/skia/include/core/SkRect.h"
#import "third_party/skia/modules/skparagraph/include/Paragraph.h"

FLUTTER_ASSERT_ARC

const flutter::TextRange normalize(const flutter::TextSelection& selection) {
  if (selection.first <= selection.second) {
    return {selection.first, selection.second - selection.first};
  }
  return {selection.second, selection.first - selection.second};
}

@interface _FlutterTextPosition : UITextPosition
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly) UITextStorageDirection affinity;
+ (instancetype)positionWithIndex:(NSUInteger)index;
+ (instancetype)positionWithIndex:(NSUInteger)index affinity:(UITextStorageDirection)affinity;
- (instancetype)initWithIndex:(NSUInteger)index affinity:(UITextStorageDirection)affinity;
@end

@implementation _FlutterTextPosition

+ (instancetype)positionWithIndex:(NSUInteger)index {
  return [[_FlutterTextPosition alloc] initWithIndex:index affinity:UITextStorageDirectionForward];
}
+ (instancetype)positionWithIndex:(NSUInteger)index affinity:(UITextStorageDirection)affinity {
  return [[_FlutterTextPosition alloc] initWithIndex:index affinity:affinity];
}

- (instancetype)initWithIndex:(NSUInteger)index affinity:(UITextStorageDirection)affinity {
  self = [super init];
  if (self) {
    _index = index;
    _affinity = affinity;
  }
  return self;
}
@end

/// Convenience extension for casting UITextRange to FlutterTextSelection
@interface UITextRange ()
- (flutter::TextSelection)selection;
- (flutter::TextRange)range;
@end
/// Convenience extension for casting UITextPosition to _FlutterTextPosition
@interface UITextPosition ()
- (NSUInteger)index;
@end

@interface FlutterTextSelection : UITextRange
@property(nonatomic, readonly) flutter::TextSelection selection;
+ (instancetype)range:(flutter::TextRange)range;
- (instancetype)initWithRange:(flutter::TextRange)range;
- (instancetype)initWithSelection:(flutter::TextSelection)selection;
@end

@implementation FlutterTextSelection
+ (instancetype)range:(flutter::TextRange)range {
  return [[FlutterTextSelection alloc] initWithRange:range];
}

- (instancetype)initWithRange:(flutter::TextRange)range {
  return self = [self initWithSelection:{range.first, range.first + range.second}];
}
- (instancetype)initWithSelection:(flutter::TextSelection)selection {
  self = [super init];
  if (self) {
    _selection = selection;
  }
  return self;
}

- (UITextPosition*)start {
  return [_FlutterTextPosition positionWithIndex:_selection.first];
}

- (UITextPosition*)end {
  return [_FlutterTextPosition positionWithIndex:_selection.second];
}
- (flutter::TextRange)range {
  return normalize(_selection);
}

- (BOOL)isEmpty {
  return self.selection.first == self.selection.second;
}
@end

@interface TextSelectionRect : UITextSelectionRect

- (instancetype)initWithTextBox:(txt::Paragraph::TextBox&)textBox
                  containsStart:(BOOL)containsStart
                    containsEnd:(BOOL)containsEnd;
@end

@implementation TextSelectionRect

@synthesize rect = _rect;
@synthesize writingDirection = _writingDirection;
@synthesize containsStart = _containsStart;
@synthesize containsEnd = _containsEnd;

- (instancetype)initWithTextBox:(txt::Paragraph::TextBox&)textBox
                  containsStart:(BOOL)containsStart
                    containsEnd:(BOOL)containsEnd {
  if (self = [super init]) {
    const SkRect rect = textBox.rect;
    _rect = CGRectMake(rect.left(), rect.top(), rect.width(), rect.height());
    switch (textBox.direction) {
      case txt::TextDirection::ltr:
        _writingDirection = NSWritingDirectionLeftToRight;
        break;
      case txt::TextDirection::rtl:
        _writingDirection = NSWritingDirectionRightToLeft;
        break;
    }
    _containsEnd = containsEnd;
  }
  return self;
}

- (BOOL)isVertical {
  return false;
}

@end

@implementation FlutterTextInputClientView {
  flutter::UiTextInputModel* _textInputState;
  UITextInputStringTokenizer* _tokenizer;
}

- (instancetype)initWithTextInputModel:(flutter::UiTextInputModel&)model {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _textInputState = &model;
    _textInputState->notifyIMEEditingStateWillChange = [&self](size_t flag) {
      [self editingStateWillChange:flag];
    };
    _textInputState->notifyIMEEditingStateDidChange = [&self](size_t flag) {
      [self editingStateDidChange:flag];
    };
  }
  return self;
}

- (void)updateTextInputConfiguration:(NSDictionary*)configuration {
  // NSLog(@"configuration: %@", configuration);
  self.inlinePredictionType = UITextInlinePredictionTypeYes;
}

// Informs the IME that the editing state will change.
- (void)editingStateWillChange:(size_t)flag {
  // NSLog(@"editingStateWillChange: %lu, delegate: %@\n", flag, self.inputDelegate);
  if (flag & 1) {
    [self.inputDelegate selectionWillChange:self];
  }
  if (flag >> 1) {
    [self.inputDelegate textWillChange:self];
  }
}

// Informs the IME that the editing state has changed.
- (void)editingStateDidChange:(size_t)flag {
  // NSLog(@"editingStateDidChange: %lu, delegate: %@\n", flag, self.inputDelegate);
  if (flag & 1) {
    [self.inputDelegate selectionDidChange:self];
  }
  if (flag >> 1) {
    [self.inputDelegate textDidChange:self];

    // auto notification = [[NSNotification alloc] initWithName:UITextViewTextDidChangeNotification
    // object:self userInfo:nil];

    // Is this notification private?
    auto notification = [[NSNotification alloc] initWithName:@"UITextSelectionDidScroll"
                                                      object:self
                                                    userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
  }
}

- (void)replaceText:(NSString*)replacementText
              range:(const flutter::TextRange&)replaceRange
        markedRange:(const flutter::TextRange&)markedRange
     selectionRange:(const flutter::TextSelection&)selectionRange {
  std::function<void(size_t)> willChange = [&](size_t flag) { [self editingStateWillChange:flag]; };
  std::function<void(size_t)> didChange = [&](size_t flag) {
    _textInputState->onEditingStateChanged(flag);
    [self editingStateDidChange:flag];
  };

  const char16_t* data = (const char16_t*)CFStringGetCStringPtr(
      (__bridge CFStringRef)replacementText, kCFStringEncodingUTF16LE);
  if (data || !replacementText) {
    return _textInputState->replaceText(std::u16string_view(data, replacementText.length),
                                        replaceRange, markedRange, selectionRange, nullptr,
                                        didChange);
  }
  // TODO:
  //  const char* latin1 = replacementText.UTF8String;
  //  NSLog(@"latin1? %s\n", latin1);
  //  std::u16string_view string = std::u16string_view(reinterpret_cast<const
  //  char16_t*>([replacementText characterAtIndex:0]), replacementText.length);
  std::u16string string = std::u16string(replacementText.length, 0);
  [replacementText getCharacters:(unichar*)string.data()];
  _textInputState->replaceText(string, replaceRange, markedRange, selectionRange, nullptr,
                               didChange);
}

#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder {
  return true;
}

#pragma mark - UIKeyInput

- (BOOL)hasText {
  return !_textInputState->text().empty();
}

- (void)insertText:(NSString*)text {
  const flutter::TextRange& composing = _textInputState->composing();
  const flutter::TextRange& selection = normalize(_textInputState->selection());
  const flutter::TextRange& range = composing.second != 0 ? composing : selection;
  [self replaceText:text
               range:range
         markedRange:{0, 0}
      selectionRange:{range.first + text.length, range.first + text.length}];
  NSLog(@"insertText ended: %@\n",
        [NSString stringWithCharacters:(const unichar*)_textInputState->text().data()
                                length:_textInputState->text().size()]);
}

- (void)deleteBackward {
  // So far it seems the IME won't call this method
  // when the marked text range is not nil.
  const flutter::TextRange& selected = normalize(_textInputState->selection());
  flutter::TextRange range = selected;
  // FIXME:
  if (selected.second == 0) {
    if (selected.first == 0) {
      return;
    }
    _FlutterTextPosition* caret = [_FlutterTextPosition positionWithIndex:selected.first];
    _FlutterTextPosition* newStart =
        (_FlutterTextPosition*)[self.tokenizer positionFromPosition:caret
                                                         toBoundary:UITextGranularityCharacter
                                                        inDirection:UITextLayoutDirectionLeft];
    if (!newStart) {
      return;
    }
    range = {newStart.index, 1};
  }
  NSLog(@"deleteBackward: %lu, %lu\n", range.first, range.second);
  [self replaceRange:[FlutterTextSelection range:range] withText:@""];
}

- (BOOL)isEditable {
  return true;
}

- (UITextInputStringTokenizer*)tokenizer {
  if (_tokenizer) {
    return _tokenizer;
  }
  return _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
}

- (UIView*)textInputView {
  return self;
}

- (BOOL)supportsAdaptiveImageGlyph {
  return false;
}

#pragma mark - UITextInput: Replacing and returning text

- (NSString*)textInRange:(UITextRange*)range {
  const auto text = _textInputState->text();
  const auto [startIndex, length] = range.range;
  static_assert(sizeof(unichar) == sizeof(char16_t), "???");
  return [NSString stringWithCharacters:(unichar*)(text.data() + startIndex) length:length];
}

- (void)replaceRange:(UITextRange*)range withText:(NSString*)text {
  const flutter::TextRange replaceRange = range.range;
  [self replaceText:text
               range:replaceRange
         markedRange:{0, 0}
      selectionRange:{replaceRange.first + text.length, replaceRange.first + text.length}];
}

- (BOOL)shouldChangeTextInRange:(UITextRange*)range replacementText:(NSString*)text {
  return true;
}

#pragma mark - UITextInput: Working with marked and selected text

- (FlutterTextSelection*)selectedTextRange {
  return [[FlutterTextSelection alloc] initWithSelection:_textInputState->selection()];
}
- (void)setSelectedTextRange:(UITextRange*)selectedTextRange {
  NSLog(@"setSelectedTextRange: (%lu, %lu) \n", selectedTextRange.selection.first,
        selectedTextRange.selection.second);
  return [self replaceText:nil
                     range:{0, 0}
               markedRange:_textInputState->composing()
            selectionRange:selectedTextRange.selection];
}

- (FlutterTextSelection*)markedTextRange {
  const flutter::TextRange& range = _textInputState->composing();
  return range.second == 0 ? nil : [FlutterTextSelection range:range];
}

- (void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)selectedRange {
  const UITextRange* replaceRange = self.markedTextRange ?: self.selectedTextRange;
  if (replaceRange == nil) {
    return;
  }
  const size_t startIndex = replaceRange.range.first;
  NSLog(@"setMarkedText: %@, markedRange: {%lu, %lu}, selected: {%lu, %lu}\n", markedText,
        startIndex, markedText.length, startIndex + selectedRange.location,
        startIndex + selectedRange.location + selectedRange.length);

  [self replaceText:markedText
               range:replaceRange.range
         markedRange:{startIndex, markedText.length}
      selectionRange:{startIndex + selectedRange.location,
                      startIndex + selectedRange.location + selectedRange.length}];
}

- (void)setAttributedMarkedText:(NSAttributedString*)markedText
                  selectedRange:(NSRange)selectedRange {
  // TODO: implement
  [self setMarkedText:markedText.string selectedRange:selectedRange];
}

- (void)unmarkText {
  [self replaceText:nil
               range:{0, 0}
         markedRange:{0, 0}
      selectionRange:_textInputState->selection()];
}

#pragma mark - UITextInput: Computing text ranges and text positions

- (UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition
                           toPosition:(UITextPosition*)toPosition {
  return [[FlutterTextSelection alloc] initWithSelection:{fromPosition.index, toPosition.index}];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {
  const int64_t index = position.index + offset;
  // NSLog(@"positionFromPosition: %ld + %ld = %lld\n", position.index, offset, index);
  if (index < 0 || (int64_t)_textInputState->text().length() < index) {
    return nil;
  }
  return [_FlutterTextPosition positionWithIndex:index];
}

// Cursor movement
- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                            inDirection:(UITextLayoutDirection)direction
                                 offset:(NSInteger)offset {
  switch (direction) {
    case UITextLayoutDirectionUp:
    case UITextLayoutDirectionDown:
      NSAssert(false, @"implement");
      return nil;
    case UITextLayoutDirectionLeft:
      return [self positionFromPosition:position offset:-offset];
    case UITextLayoutDirectionRight:
      return [self positionFromPosition:position offset:offset];
  };
}

- (UITextPosition*)beginningOfDocument {
  return [_FlutterTextPosition positionWithIndex:0];
}

- (UITextPosition*)endOfDocument {
  return [_FlutterTextPosition positionWithIndex:_textInputState->text().length()];
}

#pragma mark - UITextInput: Evaluating text positions

- (NSComparisonResult)comparePosition:(UITextPosition*)position toPosition:(UITextPosition*)other {
  if (position.index > other.index) {
    return NSOrderedDescending;
  } else if (position.index < other.index) {
    return NSOrderedAscending;
  }
  return NSOrderedSame;
}

- (NSInteger)offsetFromPosition:(UITextPosition*)from toPosition:(UITextPosition*)toPosition {
  return (int)toPosition.index - from.index;
}

#pragma mark - UITextInput: Reconciling text position and character offset

//- (UITextPosition *)positionWithinRange:(UITextRange *)range atCharacterOffset:(NSInteger)offset {
//  NSAssert(false, @"unimplemented");
//}
//
//- (NSInteger)characterOffsetOfPosition:(UITextPosition *)position withinRange:(UITextRange *)range
//{
//  NSAssert(false, @"unimplemented");
//}

#pragma mark - UITextInput: Determining layout and writing direction

- (UITextPosition*)positionWithinRange:(UITextRange*)range
                   farthestInDirection:(UITextLayoutDirection)direction {
  NSAssert(false, @"unimplemented");
  return range.end;
}

- (UITextRange*)characterRangeByExtendingPosition:(UITextPosition*)position
                                      inDirection:(UITextLayoutDirection)direction {
  NSAssert(false, @"unimplemented");
  return [[FlutterTextSelection alloc] initWithSelection:{0, 0}];
}

- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition*)position
                                          inDirection:(UITextStorageDirection)direction {
  return NSWritingDirectionLeftToRight;
}

- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection forRange:(UITextRange*)range {
  // FIXME:
}

#pragma mark - UITextInput: Working with geometry and hit-testing

- (CGRect)firstRectForRange:(UITextRange*)range {
  const auto [start, length] = range.range;
  const bool isEmpty = length == 0;
  txt::Paragraph* paragraph = &_textInputState->getParagraph();
  const int lineNumber = paragraph->GetLineNumberAt(start);
  skia::textlayout::LineMetrics lineMetrics;
  if (lineNumber < 0 || !paragraph->GetLineMetricsAt(lineNumber, &lineMetrics)) {
    return CGRectZero;
  }
  const size_t end = MIN(lineMetrics.fEndIndex, start + length);
  // trailing spaces ???
  // TODO: +1 bad
  // const flutter::TextRange firstRectRange = {start, isEmpty ? end + 1 : end};
  const std::vector<txt::Paragraph::TextBox> textBoxes = paragraph->GetRectsForRange(
      start, isEmpty ? end + 1 : end, txt::Paragraph::RectHeightStyle::kMax,
      txt::Paragraph::RectWidthStyle::kTight);
  if (textBoxes.empty()) {
    NSAssert(false, @"range %lu, %lu has no text boxes.\n", start, length);
    return CGRectZero;
  }
  SkRect rect = textBoxes[0].rect;
  for (size_t i = 1; i < textBoxes.size(); i++) {
    rect.joinPossiblyEmptyRect(textBoxes[i].rect);
  }
  return CGRectMake(rect.left(), rect.top(), isEmpty ? 0 : rect.width(), rect.height());
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
  if (_textInputState->text().length() == 0) {
    return nil;
  }
  txt::Paragraph* paragraph = &_textInputState->getParagraph();
  const size_t index = paragraph->GetGlyphPositionAtCoordinate(point.x, point.y).position;
  return [_FlutterTextPosition positionWithIndex:index];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {
  NSAssert(false, @"unimplemented");

  return [self closestPositionToPoint:point];
}

- (NSArray<UITextSelectionRect*>*)selectionRectsForRange:(UITextRange*)range {
  txt::Paragraph* paragraph = &_textInputState->getParagraph();
  const auto [start, end] = range.range;
  std::vector<txt::Paragraph::TextBox> textBoxes = paragraph->GetRectsForRange(
      start, end, txt::Paragraph::RectHeightStyle::kMax, txt::Paragraph::RectWidthStyle::kTight);

  NSMutableArray* rects = [[NSMutableArray alloc] initWithCapacity:textBoxes.size()];
  // TODO: bidi
  for (size_t i = 0; i < textBoxes.size(); i++) {
    rects[i] = [[TextSelectionRect alloc] initWithTextBox:textBoxes[i]
                                            containsStart:i == 0
                                              containsEnd:i + 1 == textBoxes.size()];
  }
  return rects;
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
  skia::textlayout::Paragraph::GlyphInfo info;
  txt::Paragraph* paragraph = &_textInputState->getParagraph();
  if (!paragraph->GetClosestGlyphInfoAtCoordinate(point.x, point.y, &info)) {
    return nil;
  }
  const SkRect rect = {static_cast<float>(point.x), static_cast<float>(point.y)};
  return info.fGraphemeLayoutBounds.contains(rect)
             ? [FlutterTextSelection
                   range:{info.fGraphemeClusterTextRange.start, info.fGraphemeClusterTextRange.end}]
             : nil;
}

#pragma mark - UITextInput: Providing the caret layout information
- (CGRect)caretRectForPosition:(UITextPosition*)position {
  // FIXME:
  skia::textlayout::Paragraph::GlyphInfo info;
  txt::Paragraph* paragraph = &_textInputState->getParagraph();
  const auto atEnd = position.index == _textInputState->text().length();
  // TODO: handle empty text
  if (!paragraph->GetGlyphInfoAt(atEnd ? position.index - 1 : position.index, &info)) {
    return CGRectZero;
  }
  const SkRect rect = info.fGraphemeLayoutBounds;
  // TODO: affinity.
  return CGRectMake(atEnd ? rect.right() : rect.left(), rect.top(), 2, rect.height());
}

// Assume identity transform.
//- (CGAffineTransform)caretTransformForPosition:(UITextPosition *)position {
//
//}

#pragma mark - UITextInput: Managing the floating cursor

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
}

- (void)endFloatingCursor {
}

#pragma mark - UITextInput: Using dictation

- (void)dictationRecordingDidEnd {
}

- (void)dictationRecognitionFailed {
}

//- (void)insertDictationResult:(NSArray<UIDictationPhrase*>*)dictationResult {
//}

//- (id)insertDictationResultPlaceholder {
//}
//
//- (CGRect)frameForDictationResultPlaceholder:(id)placeholder {
//}

- (void)removeDictationResultPlaceholder:(id)placeholder willInsertResult:(BOOL)willInsertResult {
}

#pragma mark - UITextInput: Managing placeholders

- (UITextPlaceholder*)insertTextPlaceholderWithSize:(CGSize)size {
  NSAssert(false, @"unimplemented");
  return nil;
}

- (void)removeTextPlaceholder:(UITextPlaceholder*)textPlaceholder {
  NSAssert(false, @"unimplemented");
}

#pragma mark - UITextInput: Managing the edit menu (using default impl)
//- (UIMenu *)editMenuForTextRange:(UITextRange *)textRange suggestedActions:(NSArray<UIMenuElement
//*> *)suggestedActions {
//
//}

//- (void)willPresentEditMenuWithAnimator:(id<UIEditMenuInteractionAnimating>)animator {
//}

//- (void)willDismissEditMenuWithAnimator:(id<UIEditMenuInteractionAnimating>)animator {
//
//}

#pragma mark - UITextInput: Supporting text-phrase alternatives

- (void)insertText:(NSString*)text
      alternatives:(NSArray<NSString*>*)alternatives
             style:(UITextAlternativeStyle)style {
  NSAssert(false, @"unimplemented");
}

#pragma mark - UITextInput: Inserting a Smart Reply suggestion

- (void)insertInputSuggestion:(UIInputSuggestion*)inputSuggestion {
  NSAssert(false, @"unimplemented");
}

#pragma mark - UITextInput: Supporting adaptive images

- (void)insertAdaptiveImageGlyph:(NSAdaptiveImageGlyph*)adaptiveImageGlyph
                replacementRange:(UITextRange*)replacementRange {
  NSAssert(false, @"unimplemented");
}

#pragma mark - UITextInput: Returning text-styling information
// Called by -[UIResponder(UITextInput_Internal) _fontForCaretSelection]
//- (NSDictionary<NSAttributedStringKey,id> *)textStylingAtPosition:(UITextPosition *)position
// inDirection:(UITextStorageDirection)direction {
//  NSAssert(false, @"unimplemented");
//  return @{};
//}

#pragma mark - UITextInput: ???

//- (NSAttributedString *)attributedTextInRange:(UITextRange *)range {
//  NSAssert(false, @"unimplemented");
//}

- (void)insertAttributedText:(NSAttributedString*)string {
  NSAssert(false, @"unimplemented");
  return [self insertText:string.string];
}

- (void)replaceRange:(UITextRange*)range withAttributedText:(NSAttributedString*)attributedText {
  NSAssert(false, @"unimplemented");
  return [self replaceRange:range withText:attributedText.string];
}

- (void)willPresentWritingTools {
}
- (void)didDismissWritingTools {
}

@end

@implementation FlutterTextInputClientView (ARROW)

- (void)pressesBegan:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {
  [self.nextResponder.nextResponder.nextResponder pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {
  [self.nextResponder.nextResponder.nextResponder pressesEnded:presses withEvent:event];
}

- (void)pressesChanged:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {
  [self.nextResponder.nextResponder.nextResponder pressesChanged:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event {
  [self.nextResponder.nextResponder.nextResponder pressesCancelled:presses withEvent:event];
}

@end
