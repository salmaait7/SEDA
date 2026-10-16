#!/usr/bin/env ruby

require_relative "local_transient"

# Paramètre du score local
Z_THRESHOLD = 3.0

unless ARGV.length == 4
  abort(
    "Usage: ruby score_activity.rb " \
    "ENVELOPE.json INPUT_DIR clean|trojan OUTPUT_DIR"
  )
end

envelope_file, input_root, variant, output_dir = ARGV

unless %w[clean trojan].include?(variant)
  abort("La variante doit être 'clean' ou 'trojan'")
end

# Lecture de la référence clean
model = LocalTransient.load_model(envelope_file)

# Recherche des fichiers à évaluer
files = LocalTransient.activity_files(input_root)
abort("Aucun CSV d'activité trouvé dans #{input_root}") if files.empty?

# Noms automatiques des fichiers de résultats
run_output = File.join(output_dir, "#{variant}_run_scores.csv")
local_output = File.join(output_dir, "#{variant}_local_scores.csv")

# Calcul et enregistrement des scores
count = LocalTransient.write_scores(
  model,
  files: files,
  variant: variant,
  run_output: run_output,
  local_output: local_output,
  exclude_training: variant == "clean",
  z_threshold: Z_THRESHOLD
)

if count.zero?
  abort("Aucun run évalué ")
end

puts "Variante : #{variant}"
puts "Runs évalués : #{count}"
puts "Scores par run : #{File.expand_path(run_output)}"
puts "Détails par transition : #{File.expand_path(local_output)}"