
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/input/text_input_model.h"
#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <string_view>
#include <type_traits>
#include "dart_api.h"
#include "lib/ui/text/paragraph.h"
#include "lib/ui/ui_dart_state.h"

namespace flutter {

IMPLEMENT_WRAPPERTYPEINFO(ui, UiTextInputModel);

// static
void UiTextInputModel::Create(
    Dart_Handle wrapper,
    Dart_Handle on_text_editing_state_updated_callback,
    Dart_Handle paragraphGetter,
    Dart_Handle paragraphOffsetXGetter,
    Dart_Handle paragraphOffsetYGetter) {
  UIDartState::ThrowIfUIOperationsProhibited();
  fml::RefPtr<UiTextInputModel> res = fml::MakeRefCounted<UiTextInputModel>();
  res->AssociateWithDartWrapper(wrapper);

  res->update_callback_.Set(tonic::DartState::Current(),
                            on_text_editing_state_updated_callback);

  res->get_paragraph_callback_.Set(tonic::DartState::Current(),
                                   paragraphGetter);
}

UiTextInputModel::UiTextInputModel() {}

Dart_Handle UiTextInputModel::getText() {
  // TODO: cache?
  // TODO: latin1
  return Dart_NewStringFromUTF16(
      reinterpret_cast<const uint16_t*>(text_.data()), text_.size());
}
Dart_Handle UiTextInputModel::getSelectionRange() {
  std::vector<size_t> result = {selection_.first, selection_.second};
  return tonic::DartConverter<decltype(result)>::ToDart(result);
}

Dart_Handle UiTextInputModel::getComposingRange() {
  if (composing_.second == 0) {
    return Dart_Null();
  }
  std::vector<size_t> result = {composing_.first, composing_.second};
  return tonic::DartConverter<decltype(result)>::ToDart(result);
}

void UiTextInputModel::replaceText(
    const std::u16string_view& replacementText,
    const TextRange range,
    const TextRange composing,
    const TextSelection selection,
    std::function<void(size_t)> editingStateWillChange,
    std::function<void(size_t)> editingStateDidChange) {
  TextRange normalizedComposing = composing;
  if (composing.second == 0) {
    normalizedComposing = {0, 0};
  }
  const bool textWillChange =
      text_.compare(range.first, range.second, replacementText);

  const size_t changeType = (selection != selection_) |
                            ((normalizedComposing != composing_) << 1) |
                            (textWillChange << 2);
  if (changeType != 0 && editingStateWillChange) {
    editingStateWillChange(changeType);
  }

  selection_ = selection;
  composing_ = normalizedComposing;
  if (textWillChange) {
    text_.replace(range.first, range.second, replacementText);
  }
  if (changeType != 0 && editingStateDidChange) {
    editingStateDidChange(changeType);
  }
}

void UiTextInputModel::replace(Dart_Handle replacementText,
                               size_t rangeStart,
                               size_t rangeLength,
                               size_t composingStart,
                               size_t composingLength,
                               size_t selectionStart,
                               size_t selectionEnd) {
  replaceText(
      std::u16string_view(
          tonic::DartConverter<std::u16string>::FromDart(replacementText)),
      {rangeStart, rangeLength}, {composingStart, composingLength},
      {selectionStart, selectionEnd}, notifyIMEEditingStateWillChange,
      notifyIMEEditingStateDidChange);
}

void UiTextInputModel::attach(Dart_Handle data) {
  if (!connection_) {
   connection_ = UIDartState::Current()
                    ->GetTextInputConnectionFactory()
                    .CreateTextInputConnection(*this, data);
  }
}

void UiTextInputModel::detach() {
  
}

void UiTextInputModel::setTextInputConfiguration(Dart_Handle data) {}

void UiTextInputModel::setSizeAndTransform(Dart_Handle data) {
  if (!connection_) {
    return;
  }
  double array[16];
  {
    auto list = tonic::Float64List(data);
    memcpy(array, list.data(), 16 * sizeof(double));
  }
  connection_->SetSizeAndTransform(array[0], array[1], array + 2);
}

void UiTextInputModel::dispose() {
  //
}

txt::Paragraph& UiTextInputModel::getParagraph() {
  tonic::DartState::Scope scope(get_paragraph_callback_.dart_state().lock());
  Dart_Handle paragraph =
      tonic::DartInvoke(get_paragraph_callback_.value(), {});
  // printf("handle error: %s, paragraph: %p\n", Dart_GetError(paragraph),
  //        paragraph);
  auto wrapper = tonic::DartConverter<Paragraph*>::FromDart(paragraph);
  return *wrapper->m_paragraph_;
}

}  // namespace flutter
