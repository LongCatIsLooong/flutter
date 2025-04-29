// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_

#import <UIKit/UIKit.h>
// #import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"

namespace flutter {
class UiTextInputModel;
}
@interface FlutterTextInputClientView : UIView <UITextInput>

@property(nonatomic, weak) id<UITextInputDelegate> inputDelegate;

@property(nonatomic, copy) NSDictionary<NSString*, id>* markedTextStyle;

// FIXME:
@property(nonatomic) UITextStorageDirection selectionAffinity;

#pragma mark UITextInputTraits
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType;
@property(nonatomic) BOOL enablesReturnKeyAutomatically;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property(nonatomic, getter=isEnableDeltaModel) BOOL enableDeltaModel;

@property(nonatomic) UITextInlinePredictionType inlinePredictionType;
@property(nonatomic) UITextSmartQuotesType smartQuotesType API_AVAILABLE(ios(11.0));
@property(nonatomic) UITextSmartDashesType smartDashesType API_AVAILABLE(ios(11.0));
@property(nonatomic, copy) UITextContentType textContentType API_AVAILABLE(ios(10.0));

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithTextInputModel:(flutter::UiTextInputModel&)model NS_DESIGNATED_INITIALIZER;

- (void)updateTextInputConfiguration:(NSDictionary*)configuration;
@end

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_
