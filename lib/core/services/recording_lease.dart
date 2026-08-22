import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecordingOwner { activeRun, racer }

class RecordingLease {
  RecordingOwner? _owner;

  RecordingOwner? get owner => _owner;

  void acquire(RecordingOwner requested) {
    final current = _owner;
    if (current != null) {
      throw StateError(
        current == RecordingOwner.racer
            ? 'Finish or cancel Racer before starting a trip.'
            : 'Finish the active trip before arming Racer.',
      );
    }
    _owner = requested;
  }

  void release(RecordingOwner owner) {
    if (_owner == owner) _owner = null;
  }
}

final recordingLeaseProvider = Provider<RecordingLease>(
  (_) => RecordingLease(),
);
