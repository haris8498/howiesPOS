import '../errors/failures.dart';

/// A generic Result type representing either Success [T] or Failure [Failure].
class Result<T, E extends Failure> {
  final T? _data;
  final E? _failure;
  final bool isSuccess;

  const Result.success(T data)
      : _data = data,
        _failure = null,
        isSuccess = true;

  const Result.failure(E failure)
      : _data = null,
        _failure = failure,
        isSuccess = false;

  bool get isFailure => !isSuccess;

  T get data {
    if (!isSuccess) {
      throw StateError('Cannot access data on a failed Result: $_failure');
    }
    return _data as T;
  }

  E get failure {
    if (isSuccess) {
      throw StateError('Cannot access failure on a successful Result');
    }
    return _failure as E;
  }

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(E failure) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(_data as T);
    } else {
      return onFailure(_failure as E);
    }
  }
}
