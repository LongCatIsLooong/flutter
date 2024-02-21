// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

abstract base class RunMergingIterator<T, RunAttribute> implements Iterator<(int, T)> {
  RunMergingIterator(this._rawAttributes, T initialValue)
    : _current = (0, initialValue);

  final List<Iterator<(int, RunAttribute)>?> _rawAttributes;
  late final List<Iterator<(int, RunAttribute)>> _attributes = _rawAttributes as List<Iterator<(int, RunAttribute)>>;

  // The number of attributes in [attributes] that has not reached end. This
  // value being 0 indicates that this iterator has reached end.
  late int _remainingLength; // This is initialized in _initialize().

  late bool _emitBaseValue = _initialize();

  @override
  (int, T) get current => _current;
  (int, T) _current;

  // Throw exhausted attributes out of the list bounds. Returns the new list length.
  // As a side effect, this function also calls `moveNext` on all iterators in
  // the list.
  bool _initialize() {
    int end = _rawAttributes.length - 1;
    bool emitBaseValue = true;
    for (int i = 0; i <= end; i += 1) {
      if (_rawAttributes[i]?.moveNext() ?? false) {
        emitBaseValue = emitBaseValue && _rawAttributes[i]?.current.$1 != 0;
        continue;
      }
      while (!(_rawAttributes[end]?.moveNext() ?? false)) {
        if (end <= i + 1) {
          _remainingLength = i;
          return emitBaseValue;
        }
        end -= 1;
        assert(end > i);
      }
      assert(_rawAttributes[end]?.current != null);
      // Throws the current i-th attribute away.
      _rawAttributes[i] = _rawAttributes[end];
      emitBaseValue = emitBaseValue && _rawAttributes[i]?.current.$1 != 0;
    }
    _remainingLength = end + 1;
    return emitBaseValue;
  }

  // Move Iterators in the attributes list with the smallest starting index
  // to the start of the attributes list.
  int _moveNextAttributesToHead(int remainingLength) {
    assert(remainingLength > 0);
    int runStartIndex = -1;
    // The number of attributes that currently start at runStartIndex.
    int numberOfAttributes = 0;

    for (int i = 0; i < remainingLength; i += 1) {
      final Iterator<(int, RunAttribute)> attribute = _attributes[i];
      final int index = attribute.current.$1;
      if (numberOfAttributes > 0 && runStartIndex < index) {
        // This attribute has a larger startIndex than the current runStartIndex.
        continue;
      }
      if (index != runStartIndex) {
        assert(numberOfAttributes == 0 || runStartIndex > index);
        // This attribute has a smaller startIndex than the current runStartIndex.
        runStartIndex = index;
        numberOfAttributes = 1;
      } else {
        numberOfAttributes += 1;
      }
      // Move the attribute to the head of the list.
      assert(numberOfAttributes - 1 <= i);
      if (numberOfAttributes - 1 != i) {
        // Swap locations to make sure the attributes with the smallest start
        // index are relocated to the head of the list.
        _attributes[i] = _attributes[numberOfAttributes - 1];
        _attributes[numberOfAttributes - 1] = attribute;
      }
    }
    assert(numberOfAttributes > 0);
    return numberOfAttributes;
  }

  @override
  bool moveNext() {
    // If none of the attributes starts from index 0, send the baseValue first.
    if (_emitBaseValue) {
      _emitBaseValue = false;
      return true;
    }
    assert(_remainingLength >= 0);
    if (_remainingLength == 0) {
      return false;
    }
    final int numberOfAttributes = _moveNextAttributesToHead(_remainingLength);
    final int runStartIndex = _attributes[0].current.$1;
    T accumulated = current.$2;
    for (int i = numberOfAttributes - 1; i >= 0; i -= 1) {
      final Iterator<(int, RunAttribute)> runIterator = _attributes[i];
      final RunAttribute value = runIterator.current.$2;
      assert(runIterator.current.$1 == runStartIndex);
      accumulated = fold(value, accumulated);
      if (!runIterator.moveNext()) {
        // This attribute has no more starting indices, throw it out.
        _remainingLength -= 1;
        _attributes[i] = _attributes[_remainingLength];
      }
    }
    _current = (runStartIndex, accumulated);
    return _remainingLength > 0;
  }

  @pragma('vm:prefer-inline')
  T fold(RunAttribute value, T accumulatedValue);
}
