/// A write and its refresh are separate phases: retrying after a committed
/// write must never repeat the destructive operation.
enum DeletionOutcome { cancelled, failed, committed }

class DeletionCommittedException implements Exception {
  final Object cause;
  const DeletionCommittedException(this.cause);
}

class DeletionOperation {
  final Future<void> Function() delete;
  final Future<void> Function() refresh;
  bool busy = false;
  bool committed = false;
  bool refreshed = false;

  DeletionOperation({required this.delete, required this.refresh});

  Future<DeletionOutcome> run() async {
    if (busy) {
      return committed ? DeletionOutcome.committed : DeletionOutcome.cancelled;
    }
    busy = true;
    try {
      if (!committed) {
        try {
          await delete();
          committed = true;
        } on DeletionCommittedException {
          committed = true;
        }
      }
      await refresh();
      refreshed = true;
      return DeletionOutcome.committed;
    } catch (_) {
      return committed ? DeletionOutcome.committed : DeletionOutcome.failed;
    } finally {
      busy = false;
    }
  }
}
