#!/usr/bin/env ruby

require "csv"
require "fileutils"
require_relative "local_transient"

# Paramètres fixes
THRESHOLD_PERCENTILE = 0.95
METRIC = "time_z_gt3_count"

unless ARGV.length == 3
  abort(
    "Usage: ruby evaluate_detector.rb " \
    "CLEAN_SCORES.csv TROJAN_SCORES.csv OUTPUT.csv"
  )
end

clean_file, trojan_file, output_file = ARGV

# Lecture des scores
clean_rows = LocalTransient.read_run_scores(clean_file)
trojan_rows = LocalTransient.read_run_scores(trojan_file)

abort("Aucun score clean") if clean_rows.empty?
abort("Aucun score Trojan") if trojan_rows.empty?

# Regroupement par marge
clean_by_margin = clean_rows.group_by do |row|
  Integer(row.fetch("margin_percent"), 10)
end

trojan_by_margin = trojan_rows.group_by do |row|
  Integer(row.fetch("margin_percent"), 10)
end

margins = (clean_by_margin.keys & trojan_by_margin.keys).sort
abort("Aucune marge commune aux deux fichiers") if margins.empty?

# Évaluation pour chaque marge
results = margins.map do |margin|
  clean_values = clean_by_margin.fetch(margin).map do |row|
    Float(row.fetch(METRIC))
  end

  trojan_values = trojan_by_margin.fetch(margin).map do |row|
    Float(row.fetch(METRIC))
  end

  # Seuil du score global, estimé sur les runs clean
  threshold = LocalTransient.percentile(
    clean_values,
    THRESHOLD_PERCENTILE
  )

  false_positives = clean_values.count { |value| value > threshold }
  true_positives = trojan_values.count { |value| value > threshold }

  {
    margin_percent: margin,
    metric: METRIC,
    clean_validation_runs: clean_values.length,
    trojan_runs: trojan_values.length,
    threshold_percentile: THRESHOLD_PERCENTILE,
    threshold: threshold,

    false_positive_rate_percent:
      100.0 * false_positives / clean_values.length,

    true_positive_rate_percent:
      100.0 * true_positives / trojan_values.length,

    auc: LocalTransient.auc(clean_values, trojan_values),
    clean_median: LocalTransient.median(clean_values),
    trojan_median: LocalTransient.median(trojan_values)
  }
end

# Colonnes du fichier de résultats
headers = %w[
  margin_percent
  metric
  clean_validation_runs
  trojan_runs
  threshold_percentile
  threshold
  false_positive_rate_percent
  true_positive_rate_percent
  auc
  clean_median
  trojan_median
]

# Enregistrement
FileUtils.mkdir_p(File.dirname(File.expand_path(output_file)))

CSV.open(output_file, "w") do |csv|
  csv << headers

  results.each do |result|
    csv << headers.map { |header| result.fetch(header.to_sym) }
  end
end

# Affichage
puts format(
  "%-8s %10s %10s %10s",
  "Marge", "FPR (%)", "TPR (%)", "AUC"
)

results.each do |result|
  puts format(
    "%-8s %10.2f %10.2f %10.4f",
    "#{result.fetch(:margin_percent)}%",
    result.fetch(:false_positive_rate_percent),
    result.fetch(:true_positive_rate_percent),
    result.fetch(:auc)
  )
end

puts "Résultats : #{File.expand_path(output_file)}"