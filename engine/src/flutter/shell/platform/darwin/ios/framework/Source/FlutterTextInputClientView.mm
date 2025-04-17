// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FlutterTextInputClientView.h"
#import "flutter/shell/platform/darwin/ios/ios_text_input.h"
FLUTTER_ASSERT_ARC

/// Convenience extension for casting UITextRange to FlutterTextRange
@interface UITextRange ()
-(NSRange) range;
@end


@implementation FlutterTextInputClientView {
  const flutter::UiTextInputModel* _textInputState;
}

  - (instancetype)initWithTextInputModel: (const flutter::UiTextInputModel&)model {
  self = [super initWithFrame: CGRectZero];
  if (self) {
    _textInputState = &model;
  }
  return self;
}

- (void)updateTextInputConfiguration: (NSDictionary*)configuration {
}

@end
