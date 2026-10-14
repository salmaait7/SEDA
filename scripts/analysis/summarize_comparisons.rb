require "csv"
require "fileutils"

comparison_dir = ARGV[0]
output_file = ARGV[1]

unless comparison_dir && output_file
  abort(
    "Usage: ruby summarize_comparisons.rb " \
    "COMPARISON_DIR OUTPUT.csv"
  )
end

comparison_dir = File.expand_path(comparison_dir)
output_file = File.expand_path(output_file)

unless Dir.exist?(comparison_dir)
  abort(
    "[ERROR] Comparison directory not found: " \
    "#{comparison_dir}"
  )
end



def extract_metric(content, label)
  match = content.match(
    /^#{Regexp.escape(label)}\s*:\s*([-+]?\d+(?:\.\d+)?)/
  )

  match ? match[1].to_f : nil
end

def statistics(values)
  values = values.compact

  return {
    count: 0,
    mean: nil,
    std: nil,
    min: nil,
    max: nil
  } if values.empty?

  mean = values.sum.to_f / values.size

  variance =
    if values.size > 1
      values.sum do |value|
        (value - mean)**2
      end / (values.size - 1)
    else
      0.0
    end

  {
    count: values.size,
    mean: mean,
    std: Math.sqrt(variance),
    min: values.min,
    max: values.max
  }
end

def number(value, digits = 6)
  return nil if value.nil?

  format("%.#{digits}f", value)
end


comparison_files = Dir.glob(
  File.join(
    comparison_dir,
    "margin_*",
    "*_vs_reference.txt"
  )
).sort

if comparison_files.empty?
  abort(
    "[ERROR] No comparison report found in: " \
    "#{comparison_dir}"
  )
end

runs = comparison_files.map do |file|
  content = File.read(file)

  margin_name =
    File.basename(File.dirname(file))

  margin_percent =
    margin_name[/margin_(\d+)/, 1]&.to_i

  unless margin_percent
    abort(
      "[ERROR] Cannot extract margin from: #{file}"
    )
  end

  {
    file: file,
    margin: margin_percent,

    signals:
      extract_metric(content, "Signals"),

    n_changed:
      extract_metric(content, "N changed"),

    n_changed_rate:
      extract_metric(content, "N changed rate"),

    comparable_transitions:
      extract_metric(
        content,
        "Comparable transitions"
      ),

    shifted_transition_rate:
      extract_metric(
        content,
        "Shifted transition rate"
      ),

    median_delta_t:
      extract_metric(
        content,
        "Median |ΔT|"
      ),

    p95_delta_t:
      extract_metric(
        content,
        "P95 |ΔT|"
      ),

    max_delta_t:
      extract_metric(
        content,
        "Max |ΔT|"
      )
  }
end

runs_by_margin =
  runs.group_by { |run| run[:margin] }



FileUtils.mkdir_p(
  File.dirname(output_file)
)

CSV.open(output_file, "w") do |csv|
  csv << [
    "margin_percent",
    "runs",

    "signals_mean",

    "n_changed_mean",
    "n_changed_std",
    "n_changed_min",
    "n_changed_max",

    "n_changed_rate_mean_percent",
    "n_changed_rate_std_percent",

    "comparable_transitions_mean",
    "shifted_transition_rate_mean_percent",

    "median_delta_t_mean_ns",
    "median_delta_t_std_ns",

    "p95_delta_t_mean_ns",
    "p95_delta_t_std_ns",

    "max_delta_t_mean_ns",
    "max_delta_t_observed_ns"
  ]

  runs_by_margin.keys.sort.each do |margin|
    margin_runs = runs_by_margin.fetch(margin)

    signals = statistics(
      margin_runs.map { |run| run[:signals] }
    )

    n_changed = statistics(
      margin_runs.map { |run| run[:n_changed] }
    )

    n_changed_rate = statistics(
      margin_runs.map { |run| run[:n_changed_rate] }
    )

    comparable = statistics(
      margin_runs.map do |run|
        run[:comparable_transitions]
      end
    )

    shifted_rate = statistics(
      margin_runs.map do |run|
        run[:shifted_transition_rate]
      end
    )

    median_delta_t = statistics(
      margin_runs.map { |run| run[:median_delta_t] }
    )

    p95_delta_t = statistics(
      margin_runs.map { |run| run[:p95_delta_t] }
    )

    max_delta_t = statistics(
      margin_runs.map { |run| run[:max_delta_t] }
    )

    csv << [
      margin,
      margin_runs.size,

      number(signals[:mean], 2),

      number(n_changed[:mean], 2),
      number(n_changed[:std], 2),
      number(n_changed[:min], 0),
      number(n_changed[:max], 0),

      number(n_changed_rate[:mean], 6),
      number(n_changed_rate[:std], 6),

      number(comparable[:mean], 2),
      number(shifted_rate[:mean], 6),

      number(median_delta_t[:mean], 6),
      number(median_delta_t[:std], 6),

      number(p95_delta_t[:mean], 6),
      number(p95_delta_t[:std], 6),

      number(max_delta_t[:mean], 6),
      number(max_delta_t[:max], 6)
    ]
  end
end


puts
puts "=============================================================="
puts "Effect of delay variation by margin"
puts "=============================================================="
puts

puts format(
  "%-8s %-6s %-16s %-15s %-15s %-12s",
  "Margin",
  "Runs",
  "N changed",
  "Median ΔT",
  "P95 ΔT",
  "Max ΔT"
)

puts "-" * 78

runs_by_margin.keys.sort.each do |margin|
  margin_runs = runs_by_margin.fetch(margin)

  n_changed = statistics(
    margin_runs.map { |run| run[:n_changed] }
  )

  median_delta_t = statistics(
    margin_runs.map { |run| run[:median_delta_t] }
  )

  p95_delta_t = statistics(
    margin_runs.map { |run| run[:p95_delta_t] }
  )

  max_delta_t = statistics(
    margin_runs.map { |run| run[:max_delta_t] }
  )

  puts format(
    "%-8s %-6d %7.1f ± %-6.1f %7.4f ± %-5.4f %7.4f ± %-5.4f %8.4f",
    "#{margin}%",
    margin_runs.size,
    n_changed[:mean],
    n_changed[:std],
    median_delta_t[:mean],
    median_delta_t[:std],
    p95_delta_t[:mean],
    p95_delta_t[:std],
    max_delta_t[:max]
  )
end
