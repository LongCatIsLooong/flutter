// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_INPUT_TEXT_INPUT_MODEL_H_
#define FLUTTER_LIB_UI_INPUT_TEXT_INPUT_MODEL_H_

#include <algorithm>
#include <cstddef>
#include <string>
#include <tuple>
#include "flutter/lib/ui/dart_wrapper.h"
#include "flutter/lib/ui/ui_dart_state.h"
#include "fml/closure.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "third_party/tonic/typed_data/dart_byte_data.h"

namespace txt {
class Paragraph;
}
namespace flutter {
class Paragraph;
using TextRange = std::pair<size_t, size_t>;
using TextSelection = std::pair<size_t, size_t>;
class UiTextInputModel : public RefCountedDartWrappable<UiTextInputModel> {
  DEFINE_WRAPPERTYPEINFO();
  FML_FRIEND_MAKE_REF_COUNTED(UiTextInputModel);

 public:
  UiTextInputModel();

  ~UiTextInputModel() = default;

  static void Create(Dart_Handle wrapper,
                     Dart_Handle on_text_editing_state_updated_callback,
                     Dart_Handle paragraphGetter,
                     Dart_Handle paragraphOffsetXGetter,
                     Dart_Handle paragraphOffsetYGetter);

  Dart_Handle getText();
  Dart_Handle getSelectionRange();
  Dart_Handle getComposingRange();

  void replace(Dart_Handle replacementText,
               size_t rangeStart,
               size_t rangeLength,
               size_t composingStart,
               size_t composingLength,
               size_t selectionStart,
               size_t selectionEnd);

  void setTextInputConfiguration(Dart_Handle data);
  void setSizeAndTransform(Dart_Handle data);

  void attach(Dart_Handle data);
  void detach();

  void dispose();

  std::function<void(size_t)> notifyIMEEditingStateWillChange;
  std::function<void(size_t)> notifyIMEEditingStateDidChange;

  txt::Paragraph& getParagraph();
  const std::u16string& text() const { return text_; }
  const TextSelection& selection() const { return selection_; }
  const TextRange& composing() const { return composing_; }

  void replaceText(const std::u16string_view& replacementText,
                   const TextRange range,
                   const TextRange composing,
                   const TextSelection selection,
                   std::function<void(size_t)> editingStateWillChange = nullptr,
                   std::function<void(size_t)> editingStateDidChange = nullptr);

  void onEditingStateChanged(size_t change) {
    if (change == 0) {
      return;
    }
    std::shared_ptr<tonic::DartState> dart_state =
        update_callback_.dart_state().lock();
    if (!dart_state) {
      return;
    }
    tonic::DartState::Scope scope(dart_state);
    tonic::DartInvoke(update_callback_.value(), {});
  }

 private:
  std::shared_ptr<TextInputConnection> connection_;
  tonic::DartPersistentValue update_callback_;
  tonic::DartPersistentValue get_paragraph_callback_;
  tonic::DartPersistentValue get_paragraph_offset_x_callback_;
  tonic::DartPersistentValue get_paragraph_offset_y_callback_;

  std::u16string text_;
  TextSelection selection_ = {0, 0};
  TextRange composing_ = {0, 0};

  UiTextInputModel(const UiTextInputModel&) = delete;
  UiTextInputModel(UiTextInputModel&&) = delete;
  UiTextInputModel& operator=(const UiTextInputModel&) = delete;
  UiTextInputModel& operator=(UiTextInputModel&&) = delete;
};

}  // namespace flutter

#endif  // FLUTTER_LIB_UI_INPUT_TEXT_INPUT_MODEL_H_
