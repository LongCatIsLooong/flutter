// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'dart:ui';
library;

import 'dart:collection';

import 'package:meta/meta.dart' show immutable, visibleForOverriding;

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

/// Efficiently computes the [union] of a [List] of ordered [Iterator]s, and
/// returns the result as an [Iterator].
///
/// The input [List] will be mutated and must not be used again.
///
/// This class represents an operation that can be thought of as a composition
/// of [compare] and [union]: values emitted from the input [Iterator]s are first
/// sorted using [compare], and values that are deemed equal are combined into
/// a single value by using `Iterable.fold(null, union)`.
///
/// A typical use case of this is run merging:
/// ```dart
/// [(1, 'aa'), (2, 'aaa'), (3, 'a')]
/// [(2, 'b'),  (4, 'bb')]
/// ```
/// Result:
/// ```dart
/// [(1, 'aa'), (2, 'baaa'), (3, 'a'), (4, 'bb')]
/// ```
abstract base class UnionSortedIterator<Input, Output extends Object> implements Iterator<Output> {
  UnionSortedIterator(this._inputs);

  final List<Iterator<Input>?> _inputs;

  /// Compares `a` and `b`, returning a negative integer if a < b, a positive
  /// integer if a > b, or 0 if a == b.
  ///
  /// All values emitted from the input [Iterator]s that are deemed equal by
  /// [compare] will be "folded" into a single value by [union].
  @visibleForOverriding
  int compare(Input a, Input b);

  /// The union operation that will be applied to all values emitted by the input
  /// [Iterator]s which are deemed equal by the [compare] operator.
  ///
  /// The union operator should typically be commutative, as the implementation
  /// does not guarantee the order in which elements that belong to the same
  /// [compare] group will to applied.
  @visibleForOverriding
  Output union(Output? a, Input b);

  late int _remainingLength = _initialize();

  @override
  Output get current => _current;
  late Output _current;

  // Throw exhausted attributes out of the list bounds. Returns the new list length.
  // As a side effect, this function also calls `moveNext` on all iterators in
  // the list.
  int _initialize() {
    int i = 0;
    int j = _inputs.length - 1;
    while (i < j) {
      if (_inputs[i]?.moveNext() ?? false) {
        i += 1;
        continue;
      }
      // i is now points to the first empty iterator in _inputs.
      while (i < j && !(_inputs[j]?.moveNext() ?? false)) {
        j -= 1;
      }
      // j is now points to the last known non-empty iterator in _inputs.
      if (i < j) {
        _inputs[i] = _inputs[j];
        i += 1;
        j -= 1;
      }
    }
    assert(_inputs.sublist(0, i).toSet().length == i);
    return i;
  }

  // Move Iterators in the _input list with the smallest `current` value to the
  // start of the _input list.
  int _moveNextIteratorsToHead() {
    assert(_remainingLength > 0);
    if (_remainingLength == 1) {
      return 1;
    }

    Input currentMinValue = _inputs[0]!.current;
    // The number of iterators whose current value equals to `currentMinValue`.
    int numberOfMinIterators = 1;

    for (int i = 1; i < _remainingLength; i += 1) {
      final Iterator<Input> inputIterator = _inputs[i]!;
      final Input value = inputIterator.current;
      switch (compare(value, currentMinValue)) {
        case < 0:
          currentMinValue = value;
          numberOfMinIterators = 1;
        case == 0:
          numberOfMinIterators += 1;
        case _:
          continue;
      }

      // Move the iterator to the head of the _input list.
      assert(numberOfMinIterators - 1 <= i);
      if (numberOfMinIterators - 1 != i) {
        // Swap locations to make sure the Iterator with the smallest `current`
        // are relocated to the head of the list.
        _inputs[i] = _inputs[numberOfMinIterators - 1];
        _inputs[numberOfMinIterators - 1] = inputIterator;
      }
    }
    assert(numberOfMinIterators > 0);
    return numberOfMinIterators;
  }

  @override
  bool moveNext() {
    if (_remainingLength == 0) {
      return false;
    }
    assert(_remainingLength > 0);

    Output? accumulated;
    final int numberOfAttributes = _moveNextIteratorsToHead();
    assert(numberOfAttributes > 0);
    for (int i = numberOfAttributes - 1; i >= 0; i -= 1) {
      final Iterator<Input> input = _inputs[i]!;
      accumulated = union(accumulated, input.current);
      if (!input.moveNext()) {
        // This iterator is empty, throw it out.
        _remainingLength -= 1;
        _inputs[i] = _inputs[_remainingLength];
      }
    }
    _current = accumulated!;
    return true;
  }
}
