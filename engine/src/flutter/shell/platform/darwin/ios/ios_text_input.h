// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_

#include <memory>

#include "flutter/common/input/text_input_connection.h"
#include "flutter/fml/closure.h"
#include "flutter/fml/logging.h"
#import "flutter/shell/platform/darwin/common/buffer_conversions.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterCodecs.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputClientView.h"
#import "third_party/dart/runtime/include/dart_api.h"
#import "third_party/tonic/typed_data/dart_byte_data.h"

namespace flutter {
class IOSTextInputConnection : public TextInputConnection {
 public:
  IOSTextInputConnection(UiTextInputModel& model,
                         Dart_Handle textInputConfiguration,
                         __weak UIViewController* viewController)
      : flutter::TextInputConnection(model),
        view_controller_(viewController),
        text_input_([[FlutterTextInputClientView alloc] initWithTextInputModel:model]) {
    UpdateTextInputConfiguration(std::move(textInputConfiguration));
    [viewController.view addSubview:text_input_];
    [text_input_ becomeFirstResponder];
  }

  void UpdateTextInputConfiguration(Dart_Handle textInputConfiguration) override {
    NSData* data;
    {
      tonic::DartByteData typedData = tonic::DartByteData(textInputConfiguration);
      const size_t size = typedData.length_in_bytes();
      data = [NSData dataWithBytesNoCopy:typedData.data() length:size freeWhenDone:false];
    }

    id configuration = [[FlutterJSONMessageCodec sharedInstance] decode:data];
    [text_input_ updateTextInputConfiguration:configuration];
  };

  void SetSizeAndTransform(double width, double height, const double* matrix4) override {
    // Column major?
    const CATransform3D* transform = (const CATransform3D*)matrix4;
    // CGPoint origin = CGPointApplyAffineTransform(CGPointZero,
    // CATransform3DGetAffineTransform(*transform)); text_input_.frame = CGRectMake(origin.x,
    // origin.y, width, height); text_input_.frame = CGRectMake(0, 0, width, height);
    text_input_.transform = CATransform3DGetAffineTransform(*transform);
    //        auto notification = [[NSNotification alloc] initWithName:@"UITextSelectionDidScroll"
    //                                                      object:text_input_
    //                                                    userInfo:nil];
    //    [[NSNotificationCenter defaultCenter] postNotification:notification];
  }

 private:
  fml::closure callback_;
  __weak UIViewController* view_controller_;
  FlutterTextInputClientView* text_input_;
};

class IOSTextInputConnectionFactory : public TextInputConnectionFactory {
 public:
  IOSTextInputConnectionFactory() = default;

  std::shared_ptr<TextInputConnection> CreateTextInputConnection(
      UiTextInputModel& model,
      Dart_Handle textInputConfiguration) override {
    return std::make_shared<IOSTextInputConnection>(model, std::move(textInputConfiguration),
                                                    view_controller);
  }

  __weak UIViewController* view_controller;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_
