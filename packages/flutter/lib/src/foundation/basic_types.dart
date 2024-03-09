// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:meta/meta.dart' show immutable;

import 'object.dart' show objectRuntimeType;

// COMMON SIGNATURES

/// Signature for callbacks that report that an underlying value has changed.
///
/// See also:
///
///  * [ValueSetter], for callbacks that report that a value has been set.
typedef ValueChanged<T> = void Function(T value);

/// Signature for callbacks that report that a value has been set.
///
/// This is the same signature as [ValueChanged], but is used when the
/// callback is called even if the underlying value has not changed.
/// For example, service extensions use this callback because they
/// call the callback whenever the extension is called with a
/// value, regardless of whether the given value is new or not.
///
/// See also:
///
///  * [ValueGetter], the getter equivalent of this signature.
///  * [AsyncValueSetter], an asynchronous version of this signature.
typedef ValueSetter<T> = void Function(T value);

/// Signature for callbacks that are to report a value on demand.
///
/// See also:
///
///  * [ValueSetter], the setter equivalent of this signature.
///  * [AsyncValueGetter], an asynchronous version of this signature.
typedef ValueGetter<T> = T Function();

/// Signature for callbacks that filter an iterable.
typedef IterableFilter<T> = Iterable<T> Function(Iterable<T> input);

/// Signature of callbacks that have no arguments and return no data, but that
/// return a [Future] to indicate when their work is complete.
///
/// See also:
///
///  * [VoidCallback], a synchronous version of this signature.
///  * [AsyncValueGetter], a signature for asynchronous getters.
///  * [AsyncValueSetter], a signature for asynchronous setters.
typedef AsyncCallback = Future<void> Function();

/// Signature for callbacks that report that a value has been set and return a
/// [Future] that completes when the value has been saved.
///
/// See also:
///
///  * [ValueSetter], a synchronous version of this signature.
///  * [AsyncValueGetter], the getter equivalent of this signature.
typedef AsyncValueSetter<T> = Future<void> Function(T value);

/// Signature for callbacks that are to asynchronously report a value on demand.
///
/// See also:
///
///  * [ValueGetter], a synchronous version of this signature.
///  * [AsyncValueSetter], the setter equivalent of this signature.
typedef AsyncValueGetter<T> = Future<T> Function();

// LAZY CACHING ITERATOR

/// A lazy caching version of [Iterable].
///
/// This iterable is efficient in the following ways:
///
///  * It will not walk the given iterator more than you ask for.
///
///  * If you use it twice (e.g. you check [isNotEmpty], then
///    use [single]), it will only walk the given iterator
///    once. This caching will even work efficiently if you are
///    running two side-by-side iterators on the same iterable.
///
///  * [toList] uses its EfficientLength variant to create its
///    list quickly.
///
/// It is inefficient in the following ways:
///
///  * The first iteration through has caching overhead.
///
///  * It requires more memory than a non-caching iterator.
///
///  * The [length] and [toList] properties immediately pre-cache the
///    entire list. Using these fields therefore loses the laziness of
///    the iterable. However, it still gets cached.
///
/// The caching behavior is propagated to the iterators that are
/// created by [map], [where], [expand], [take], [takeWhile], [skip],
/// and [skipWhile], and is used by the built-in methods that use an
/// iterator like [isNotEmpty] and [single].
///
/// Because a CachingIterable only walks the underlying data once, it
/// cannot be used multiple times with the underlying data changing
/// between each use. You must create a new iterable each time. This
/// also applies to any iterables derived from this one, e.g. as
/// returned by `where`.
class CachingIterable<E> extends IterableBase<E> {
  /// Creates a [CachingIterable] using the given [Iterator] as the source of
  /// data. The iterator must not throw exceptions.
  ///
  /// Since the argument is an [Iterator], not an [Iterable], it is
  /// guaranteed that the underlying data set will only be walked
  /// once. If you have an [Iterable], you can pass its [iterator]
  /// field as the argument to this constructor.
  ///
  /// You can this with an existing `sync*` function as follows:
  ///
  /// ```dart
  /// Iterable<int> range(int start, int end) sync* {
  ///   for (int index = start; index <= end; index += 1) {
  ///     yield index;
  ///   }
  /// }
  ///
  /// Iterable<int> i = CachingIterable<int>(range(1, 5).iterator);
  /// print(i.length); // walks the list
  /// print(i.length); // efficient
  /// ```
  ///
  /// Beware that this will eagerly evaluate the `range` iterable, and because
  /// of that it would be better to just implement `range` as something that
  /// returns a `List` to begin with if possible.
  CachingIterable(this._prefillIterator);

  final Iterator<E> _prefillIterator;
  final List<E> _results = <E>[];

  @override
  Iterator<E> get iterator {
    return _LazyListIterator<E>(this);
  }

  @override
  Iterable<T> map<T>(T Function(E e) toElement) {
    return CachingIterable<T>(super.map<T>(toElement).iterator);
  }

  @override
  Iterable<E> where(bool Function(E element) test) {
    return CachingIterable<E>(super.where(test).iterator);
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) {
    return CachingIterable<T>(super.expand<T>(toElements).iterator);
  }

  @override
  Iterable<E> take(int count) {
    return CachingIterable<E>(super.take(count).iterator);
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) {
    return CachingIterable<E>(super.takeWhile(test).iterator);
  }

  @override
  Iterable<E> skip(int count) {
    return CachingIterable<E>(super.skip(count).iterator);
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) {
    return CachingIterable<E>(super.skipWhile(test).iterator);
  }

  @override
  int get length {
    _precacheEntireList();
    return _results.length;
  }

  @override
  List<E> toList({ bool growable = true }) {
    _precacheEntireList();
    return List<E>.of(_results, growable: growable);
  }

  void _precacheEntireList() {
    while (_fillNext()) { }
  }

  bool _fillNext() {
    if (!_prefillIterator.moveNext()) {
      return false;
    }
    _results.add(_prefillIterator.current);
    return true;
  }
}

class _LazyListIterator<E> implements Iterator<E> {
  _LazyListIterator(this._owner) : _index = -1;

  final CachingIterable<E> _owner;
  int _index;

  @override
  E get current {
    assert(_index >= 0); // called "current" before "moveNext()"
    if (_index < 0 || _index == _owner._results.length) {
      throw StateError('current can not be call after moveNext has returned false');
    }
    return _owner._results[_index];
  }

  @override
  bool moveNext() {
    if (_index >= _owner._results.length) {
      return false;
    }
    _index += 1;
    if (_index == _owner._results.length) {
      return _owner._fillNext();
    }
    return true;
  }
}

/// A factory interface that also reports the type of the created objects.
class Factory<T> {
  /// Creates a new factory.
  const Factory(this.constructor);

  /// Creates a new object of type T.
  final ValueGetter<T> constructor;

  /// The type of the objects created by this factory.
  Type get type => T;

  @override
  String toString() {
    return 'Factory(type: $type)';
  }
}

/// Linearly interpolate between two `Duration`s.
Duration lerpDuration(Duration a, Duration b, double t) {
  return Duration(
    microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t).round(),
  );
}

class FlatMapIterator<T> implements Iterator<T> {
  FlatMapIterator(this.iterators);

  final Iterator<Iterator<T>> iterators;
  Iterator<T>? _currentIterator;

  @override
  T get current => _currentIterator!.current;

  @override
  bool moveNext() {
    if (_currentIterator?.moveNext() ?? false) {
      return true;
    }
    while (iterators.moveNext()) {
      if ((_currentIterator = iterators.current).moveNext()) {
        return true;
      }
    }
    return false;
  }
}

/// A value that is either a [Left] containing a value of type [L], or a [Right]
/// containing a value of type [R].
///
/// This sealed class has two final subclasses [Left] and [Right], which can be
/// used to represent two possible types of a value, similar to nullable types.
sealed class Either<L, R> { }

/// The left branch of an [Either].
@immutable
final class Left<L, R> implements Either<L, R> {
  /// Creates a [Left] with the given `value`.
  const Left(this.value);
  /// The value of this [Left] branch.
  final L value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Left<L, Object?> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'Left')}($value)';
}

/// The right branch of an [Either].
@immutable
final class Right<L, R> implements Either<L, R> {
  /// Creates a [Right] with the given `value`.
  const Right(this.value);
  /// The value of this [Right] branch.
  final R value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Right<Object?, R> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'Right')}($value)';
}

extension NullableLeft<L extends Object, R> on Either<L, R> {
  L? get maybeLeft => switch (this) {
    Left(:final L value) => value,
    Right() => null,
  };
}

extension NullableRight<R extends Object> on Either<Object?, R> {
  R? get maybeRight => switch (this) {
    Left() => null,
    Right(:final R value) => value,
  };
}

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
