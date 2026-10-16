import 'package:reelsmith_core/reelsmith_core.dart';
import 'package:test/test.dart';

void main() {
  test('testOnlyTheExportingCaseKeepsTheScreenAwakeWhateverThePercent', () {
    expect(ExportState.exporting(0).keepsScreenAwake, isTrue);
    expect(ExportState.exporting(42).keepsScreenAwake, isTrue);
    expect(ExportState.exporting(100).keepsScreenAwake, isTrue);
    expect(ExportState.idle.keepsScreenAwake, isFalse);
    expect(ExportState.saved.keepsScreenAwake, isFalse);
    expect(ExportState.failed(false).keepsScreenAwake, isFalse);
    expect(ExportState.failed(true).keepsScreenAwake, isFalse);
  });

  test('testAlongASavedExportTheScreenIsAwakeFromTheStartToTheSave', () {
    const idle = ExportState.idle;
    final started = idle.after(ExportStateEvent.started);
    final half = started.after(ExportStateEvent.progress(0.5));
    final saved = half.after(ExportStateEvent.saved);
    final closed = saved.after(ExportStateEvent.closed);

    expect(
      [idle, started, half, saved, closed].map((state) => state.keepsScreenAwake).toList(),
      [false, true, true, false, false],
    );
  });

  test('testAlongAFailedExportTheScreenIsAwakeFromTheStartToTheFailure', () {
    const idle = ExportState.idle;
    final started = idle.after(ExportStateEvent.started);
    final failed = started.after(ExportStateEvent.failed(false));
    final closed = failed.after(ExportStateEvent.closed);

    expect(
      [idle, started, failed, closed].map((state) => state.keepsScreenAwake).toList(),
      [false, true, false, false],
    );
  });
}
