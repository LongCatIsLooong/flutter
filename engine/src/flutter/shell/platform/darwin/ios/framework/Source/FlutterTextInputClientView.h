// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_


#import <UIKit/UIKit.h>
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"

namespace flutter {
class UiTextInputModel;
}
@interface FlutterTextInputClientView : UIView //<UITextInput>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithTextInputModel: (const flutter::UiTextInputModel&) model NS_DESIGNATED_INITIALIZER;

- (void)updateTextInputConfiguration: (NSDictionary*)configuration;
@end

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERTEXTINPUTCLIENTVIEW_H_
