// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_
#define FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_

#include <cstddef>
#include <memory>
#include <string>
#include "fml/mapping.h"

namespace flutter {

class UiTextInputModel;
class TextInputConnection {
 public:
  TextInputConnection(const UiTextInputModel& model) {
    // UpdateTextInputConfiguration(std::move(textInputConfiguration));
  }

  virtual ~TextInputConnection() {}

  // virtual std::string GetText() = 0;
  // virtual void Replace(std::string_view text,
  //                      size_t range_start,
  //                      size_t range_end,
  //                      size_t selection_start,
  //                      size_t selection_end) = 0;
  virtual void UpdateTextInputConfiguration(
      fml::MallocMapping textInputConfiguration) = 0;

  TextInputConnection(const TextInputConnection&) = delete;
  TextInputConnection& operator=(const TextInputConnection&) = delete;

  //private:
  //const UiTextInputModel& model;
  //  std::weak_ptr<UiTextInputModel> model;
};

class TextInputConnectionFactory {
 public:
  TextInputConnectionFactory() = default;

  virtual ~TextInputConnectionFactory() {}

  virtual std::shared_ptr<TextInputConnection> CreateTextInputConnection(
      const UiTextInputModel& model,
      fml::MallocMapping textInputConfiguration) = 0;

  TextInputConnectionFactory(const TextInputConnectionFactory&) = delete;
  TextInputConnectionFactory& operator=(const TextInputConnectionFactory&) =
      delete;
};

}  // namespace flutter

#endif  // FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_
