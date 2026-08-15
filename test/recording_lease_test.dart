import 'package:d/core/services/recording_lease.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only one recording mode can own GPS tracking', () {
    final lease = RecordingLease();
    lease.acquire(RecordingOwner.activeRun);

    expect(lease.owner, RecordingOwner.activeRun);
    expect(
      () => lease.acquire(RecordingOwner.racer),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('active trip'),
        ),
      ),
    );
  });

  test('releasing the owner allows the other recording mode', () {
    final lease = RecordingLease();
    lease.acquire(RecordingOwner.racer);
    lease.release(RecordingOwner.activeRun);
    expect(lease.owner, RecordingOwner.racer);

    lease.release(RecordingOwner.racer);
    lease.acquire(RecordingOwner.activeRun);
    expect(lease.owner, RecordingOwner.activeRun);
  });

  test('duplicate acquisition by the same mode is rejected', () {
    final lease = RecordingLease();
    lease.acquire(RecordingOwner.racer);
    expect(
      () => lease.acquire(RecordingOwner.racer),
      throwsA(isA<StateError>()),
    );
  });
}
