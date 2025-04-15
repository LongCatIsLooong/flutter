
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/input/text_input_model.h"
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include "dart_api.h"
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

  update_callback_.Set(tonic::DartState::Current(),
                       on_text_editing_stat_updated_callback);

  connection_->SetUpdateCallback([&] {
    std::shared_ptr<tonic::DartState> dart_state =
        update_callback_.dart_state().lock();
    if (!dart_state) {
      return;
    }
    tonic::DartState::Scope scope(dart_state);
    tonic::DartInvoke(update_callback_.value(), {});
  });
}

UiTextInputModel::UiTextInputModel() {
  connection_ = UIDartState::Current()
                    ->GetTextInputConnectionFactory()
                    .CreateTextInputConnection();
}

Dart_Handle UiTextInputModel::getText() {
  // TODO: cache?
  // TODO: latin1
  return Dart_NewStringFromUTF16(reinterpret_cast<const uint16_t*>(text.data()),
                                 text.size());
}
Dart_Handle UiTextInputModel::getSelectionRange() {
  std::vector<size_t> result = {
      selection_.base(),
      selection_.extent(),
  };
  return tonic::DartConverter<decltype(result)>::ToDart(result);
}

Dart_Handle UiTextInputModel::getComposingRange() {
  if (composing_.collapsed()) {
    return Dart_Null();
  }
  std::vector<size_t> result = {
      composing_.base(),
      composing_.extent(),
  };
  return tonic::DartConverter<decltype(result)>::ToDart(result);
}

void UiTextInputModel::replace(Dart_Handle replacementText,
                               size_t rangeStart,
                               size_t rangeLength,
                               size_t composingStart,
                               size_t composingLength,
                               size_t selectionStart,
                               size_t selectionEnd) {
  composing_ = TextRange(composingStart, composingStart + composingLength);
  const size_t selection_offset = composing_.collapsed() ? 0 : composingStart;
  selection_ = TextRange(selection_offset + selectionStart,
                         selection_offset + selectionEnd);
  text_.replace(rangeStart, rangeLength, ::FromDart(replacementText));
}

void UiTextInputModel::attach(const tonic::DartByteData& data) {}
void UiTextInputModel::detach() {}

void UiTextInputModel::setTextInputConfiguration(
    const tonic::DartByteData& data) {}

void UiTextInputModel::setSizeAndTransform(const tonic::DartByteData& data) {}

void UiTextInputModel::dispose() {
  //
}

}  // namespace flutter
