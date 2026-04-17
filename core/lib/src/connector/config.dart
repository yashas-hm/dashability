/// Configuration for Dashability observation thresholds and behavior.
class DashabilityConfig {
  /// Frame time threshold in milliseconds. Frames exceeding this are
  /// considered jank. Default 16.67ms (60fps budget).
  final double jankThresholdMs;

  /// Number of widget rebuilds per second before flagging a spike.
  final int rebuildSpikeThreshold;

  /// Time window in milliseconds for batching events before analysis.
  final int batchWindowMs;

  /// How many frames to keep in the rolling window for FPS calculation.
  final int frameWindowSize;

  /// Minimum number of jank frames in a window to trigger a FrameDrop event.
  final int minJankFramesToAlert;

  const DashabilityConfig({
    this.jankThresholdMs = 16.67,
    this.rebuildSpikeThreshold = 50,
    this.batchWindowMs = 5000,
    this.frameWindowSize = 120,
    this.minJankFramesToAlert = 5,
  });

  /// Preset for profile-mode analysis with relaxed thresholds.
  const DashabilityConfig.profile()
    : jankThresholdMs = 8.33,
      // 120fps budget
      rebuildSpikeThreshold = 30,
      batchWindowMs = 3000,
      frameWindowSize = 240,
      minJankFramesToAlert = 10;
}
