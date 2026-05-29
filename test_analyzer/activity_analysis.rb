require_relative "../lib/ActivityAnalyzer/analyzer"

signals = [
  "x1", "x0", "x3", "x4", "x2",
  "y0", "y1", "y2"
] + (0..15).map { |i| "dbg_w#{i}" }

input_signals = ["x1", "x0", "x3", "x4", "x2"]

analyzer = Seda::ActivityAnalyzer.new(
  file: "activity/activity.csv",
  signals: signals,
  input_signals: input_signals
)

analyzer.run