#!/usr/bin/env ruby

require "csv"
require "fileutils"
require_relative "local_transient"

# Paramètres fixes
THRESHOLD_PERCENTILE = 0.95
METRIC = "time_z_gt3_count"

CALIBRATION_RUNS = (51..100)
TEST_RUNS = (101..150)

# Sélectionner les runs et vérifier les numéros attendus
def select_runs(rows, range, margin:, label:)
  selected = rows.select do |row|
    run_number = LocalTransient.run_from_path(row.fetch("file"))
    range.cover?(run_number)
  end

  run_numbers = selected.map do |row|
    LocalTransient.run_from_path(row.fetch("file"))
  end.sort

  unless run_numbers == range.to_a
    abort(
      "Marge #{margin} : #{label} doit contenir exactement " \
      "les runs #{range.first} à #{range.last}, sans doublons"
    )
  end

  selected
end

# Arguments
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

# Vérifier que les deux fichiers couvrent les mêmes marges
unless clean_by_margin.keys.sort == trojan_by_margin.keys.sort
  abort("Les fichiers clean et Trojan ne couvrent pas les mêmes marges")
end

margins = clean_by_margin.keys.sort

# Évaluation pour chaque marge
results = margins.map do |margin|
  # Clean 51–100 : calibration
  calibration_rows = select_runs(
    clean_by_margin.fetch(margin),
    CALIBRATION_RUNS,
    margin: margin,
    label: "la calibration clean"
  )

  # Clean 101–150 : test
  clean_test_rows = select_runs(
    clean_by_margin.fetch(margin),
    TEST_RUNS,
    margin: margin,
    label: "le test clean"
  )

  # Trojan 101–150 : test
  trojan_test_rows = select_runs(
    trojan_by_margin.fetch(margin),
    TEST_RUNS,
    margin: margin,
    label: "le test Trojan"
  )

  calibration_values = calibration_rows.map do |row|
    Float(row.fetch(METRIC))
  end

  clean_values = clean_test_rows.map do |row|
    Float(row.fetch(METRIC))
  end

  trojan_values = trojan_test_rows.map do |row|
    Float(row.fetch(METRIC))
  end

  # Seuil estimé uniquement sur la calibration clean
  threshold = LocalTransient.percentile(
    calibration_values,
    THRESHOLD_PERCENTILE
  )

  # Performances mesurées uniquement sur le test
  false_positives = clean_values.count do |value|
    value > threshold
  end

  true_positives = trojan_values.count do |value|
    value > threshold
  end

  {
    margin_percent: margin,
    metric: METRIC,
    clean_calibration_runs: calibration_values.length,
    clean_test_runs: clean_values.length,
    trojan_test_runs: trojan_values.length,
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
  clean_calibration_runs
  clean_test_runs
  trojan_test_runs
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
puts "Calibration : clean 51–100"
puts "Test : clean et Trojan 101–150"
puts

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