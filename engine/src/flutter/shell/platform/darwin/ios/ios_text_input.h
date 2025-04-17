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

namespace flutter {
class IOSTextInputConnection : public TextInputConnection {
 public:
  IOSTextInputConnection(const UiTextInputModel& model,
                         fml::MallocMapping textInputConfiguration,
                         __weak UIViewController* viewController)
      : flutter::TextInputConnection(model),
        view_controller_(viewController),
        text_input_([[FlutterTextInputClientView alloc] initWithTextInputModel:model]) {
    UpdateTextInputConfiguration(std::move(textInputConfiguration));
  }

  void UpdateTextInputConfiguration(fml::MallocMapping textInputConfiguration) override {
    id configuration = [[FlutterJSONMessageCodec sharedInstance]
        decode:ConvertMappingToNSData(std::move(textInputConfiguration))];
    [text_input_ updateTextInputConfiguration:configuration];
  };

 private:
  fml::closure callback_;
  __weak UIViewController* view_controller_;
  FlutterTextInputClientView* text_input_;
};

class IOSTextInputConnectionFactory : public TextInputConnectionFactory {
 public:
  IOSTextInputConnectionFactory() = default;

  std::shared_ptr<TextInputConnection> CreateTextInputConnection(
      const UiTextInputModel& model,
      fml::MallocMapping textInputConfiguration) override {
    return std::make_shared<IOSTextInputConnection>(model, std::move(textInputConfiguration),
                                                    view_controller);
  }

  __weak UIViewController* view_controller;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_
