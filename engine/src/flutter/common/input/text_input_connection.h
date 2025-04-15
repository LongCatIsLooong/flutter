// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_
#define FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_

#include <cstddef>
#include <memory>
#include <string>
#include "fml/closure.h"

namespace flutter {

class TextInputConnection {
 public:
  explicit TextInputConnection(fml::closure callback,
                               fml::Mapping textInputConfiguration)
      : on_editing_state_changed_(callback) {
    UpdateTextInputConfiguration(textInputConfiguration);
  }

  virtual ~TextInputConnection() {}

  virtual std::string GetCurrentText() = 0;

  virtual void SetCurrentText(std::string_view text) = 0;
  virtual void Replace(std::string_view text,
                       size_t range_start,
                       size_t range_end,
                       size_t selection_start,
                       size_t selection_end) = 0;
  virtual void UpdateTextInputConfiguration(
      fml::Mapping textInputConfiguration) = 0;

  TextInputConnection(const TextInputConnection&) = delete;
  TextInputConnection& operator=(const TextInputConnection&) = delete;

 private:
  fml::closure on_editing_state_changed_;
};

class TextInputConnectionFactory {
 public:
  TextInputConnectionFactory() = default;

  virtual ~TextInputConnectionFactory() {}

  virtual std::shared_ptr<TextInputConnection> CreateTextInputConnection(
      fml::closure callback) = 0;

  TextInputConnectionFactory(const TextInputConnectionFactory&) = delete;
  TextInputConnectionFactory& operator=(const TextInputConnectionFactory&) =
      delete;
};

}  // namespace flutter

#endif  // FLUTTER_COMMON_INPUT_TEXT_INPUT_CONNECTION_H_
