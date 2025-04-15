// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_

#include <memory>

#include "flutter/common/input/text_input_connection.h"
#include "flutter/fml/closure.h"
#include "flutter/fml/logging.h"

namespace flutter {

class IOSTextInputConnection : public TextInputConnection {
 public:
  IOSTextInputConnection(const UiTextInputModel& model,
                         fml::MallocMapping textInputConfiguration)
      : flutter::TextInputConnection(model) {
    UpdateTextInputConfiguration(std::move(textInputConfiguration));
  }

  void UpdateTextInputConfiguration(
      fml::MallocMapping textInputConfiguration) override {};

 private:
  fml::closure callback_;
};

class IOSTextInputConnectionFactory : public TextInputConnectionFactory {
 public:
  IOSTextInputConnectionFactory() = default;

  std::shared_ptr<TextInputConnection> CreateTextInputConnection(
      const UiTextInputModel& model,
      fml::MallocMapping textInputConfiguration) override {
    return std::make_shared<IOSTextInputConnection>(model, std::move(textInputConfiguration));
  }
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_TEXT_INPUT_H_
