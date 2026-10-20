#!/usr/bin/env ruby

require_relative "local_transient"

# Paramètres de l'expérience
TRAIN_RUNS = 50
SPLIT_SEED = 2026
TIME_FLOOR_NS = 0.001
MIN_SEQUENCE_SAMPLES = 3

# Arguments de la commande
unless ARGV.length == 2
  abort("Usage: ruby build_clean_envelope.rb CLEAN_DIR OUTPUT.json")
end

input_root, output_file = ARGV

# Vérification des paramètres
abort("TRAIN_RUNS doit être >= 2") if TRAIN_RUNS < 2
abort("TIME_FLOOR_NS doit être > 0") unless TIME_FLOOR_NS.positive?

unless MIN_SEQUENCE_SAMPLES.between?(2, TRAIN_RUNS)
  abort("MIN_SEQUENCE_SAMPLES doit être entre 2 et TRAIN_RUNS")
end

# Recherche des fichiers d'activité clean
files = LocalTransient.activity_files(input_root)
abort("Aucun CSV d'activité trouvé dans #{input_root}") if files.empty?

# Regroupement par marge, sans la marge zéro
groups = LocalTransient.group_files_by_margin(
  files,
  include_zero: false
)

abort("Aucune marge non nulle trouvée") if groups.empty?

# Sélection et vérification des runs d'apprentissage
expected_runs = (1..TRAIN_RUNS).to_a

groups.each do |margin, margin_files|
  training_files = margin_files.select do |file|
    LocalTransient.run_from_path(file).between?(1, TRAIN_RUNS)
  end

  run_numbers = training_files.map do |file|
    LocalTransient.run_from_path(file)
  end

  missing = expected_runs - run_numbers

  duplicates = run_numbers.tally.select do |_run, count|
    count > 1
  end.keys

  unless missing.empty?
    abort(
      "Marge #{margin} : runs d'apprentissage manquants : " \
      "#{missing.join(', ')}"
    )
  end

  unless duplicates.empty?
    abort(
      "Marge #{margin} : runs d'apprentissage dupliqués : " \
      "#{duplicates.sort.join(', ')}"
    )
  end

  groups[margin] = training_files
end

# Construction de la référence avec les seuls runs 1 à 50
model = LocalTransient.build_envelope(
  groups,
  train_count: TRAIN_RUNS,
  split_seed: SPLIT_SEED,
  time_floor_ns: TIME_FLOOR_NS,
  min_sequence_samples: MIN_SEQUENCE_SAMPLES
)

# Vérifier qu'une référence existe pour chaque marge
groups.each_key do |margin|
  margin_model = model.fetch("margins")[margin.to_s]

  if margin_model.nil? || margin_model.fetch("pairs").empty?
    abort("Aucune référence temporelle construite pour la marge #{margin}")
  end
end

# Enregistrement du modèle
LocalTransient.save_model(model, output_file)

puts "Enveloppe enregistrée : #{File.expand_path(output_file)}"
puts "Apprentissage : runs 1 à #{TRAIN_RUNS} par marge"
puts "Marges : #{model.fetch('margins').keys.map(&:to_i).sort.join(', ')}"