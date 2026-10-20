#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

PROJECT_ROOT="${PROJECT_ROOT:-/home/salma/SEDA}"
CIRCUIT="${CIRCUIT:-c432}"

DETECTOR_DIR="$PROJECT_ROOT/scripts/local_detector"
RESULTS_ROOT="$PROJECT_ROOT/results/local_detector/$CIRCUIT"

PAIRED_RUNNER="$PROJECT_ROOT/scripts/run_paired.sh"
BUILDER="$DETECTOR_DIR/build_clean_envelope.rb"
SCORER="$DETECTOR_DIR/score_activity.rb"
EVALUATOR="$DETECTOR_DIR/evaluate_detector.rb"

# Paramètres communs à toutes les simulations
MARGINS="${MARGINS:-0.05,0.10,0.15,0.20}"

NB_VECTORS="${NB_VECTORS:-100}"
NB_CYCLES="${NB_CYCLES:-$NB_VECTORS}"
STEP_TIME_NS="${STEP_TIME_NS:-40.0}"
STIMULUS_SEED="${STIMULUS_SEED:-42}"

CLEAN_VERILOG_FILE="${CLEAN_VERILOG_FILE:-$PROJECT_ROOT/data/benchmarks/clean/${CIRCUIT}.v}"
DELAY_FILE="${DELAY_FILE:-$PROJECT_ROOT/config/delay_models/gate_delays.json}"

export PROJECT_ROOT CIRCUIT
export MARGINS NB_VECTORS NB_CYCLES
export STEP_TIME_NS STIMULUS_SEED
export CLEAN_VERILOG_FILE DELAY_FILE

cd "$PROJECT_ROOT"

# Vérifier les fichiers nécessaires
for required_file in \
  "$PAIRED_RUNNER" \
  "$BUILDER" \
  "$SCORER" \
  "$EVALUATOR" \
  "$CLEAN_VERILOG_FILE" \
  "$DELAY_FILE"
do
  if [[ ! -f "$required_file" ]]; then
    echo "[ERROR] Fichier introuvable : $required_file" >&2
    exit 1
  fi
done

# Toutes les insertions du circuit sélectionné
# trojan_files=(
#   "$PROJECT_ROOT/data/benchmarks/trojan/${CIRCUIT}_"*.v
# )
trojan_files=(
  "$PROJECT_ROOT/data/benchmarks/trojan/${CIRCUIT}_buf_N154.v"
)

if [[ ${#trojan_files[@]} -eq 0 ]]; then
  echo "[ERROR] Aucun fichier Trojan pour $CIRCUIT" >&2
  exit 1
fi

# Référence clean
CLEAN_ACTIVITY="$RESULTS_ROOT/clean/activity/clean"
CLEAN_DETECTION="$RESULTS_ROOT/clean/detection"

ENVELOPE="$CLEAN_DETECTION/clean_envelope.json"
CLEAN_SCORES="$CLEAN_DETECTION/clean_run_scores.csv"

echo "=================================================="
echo "Préparation du clean commun : $CIRCUIT"
echo "=================================================="



CAMPAIGN_NAME=clean \
START_RUN=1 \
NUMBER_OF_RUNS=150 \
TROJAN_VERILOG_FILE="${trojan_files[0]}" \
ACTIVITY_ROOT="$RESULTS_ROOT/clean/activity" \
VARIANTS=clean \
bash "$PAIRED_RUNNER"


ruby "$BUILDER" \
  "$CLEAN_ACTIVITY" \
  "$ENVELOPE"

# Calculer les scores clean hors apprentissage
ruby "$SCORER" \
  "$ENVELOPE" \
  "$CLEAN_ACTIVITY" \
  clean \
  "$CLEAN_DETECTION"

# Simuler et évaluer chaque insertion successivement
for trojan_file in "${trojan_files[@]}"; do
  insertion="$(basename "$trojan_file" .v)"

  insertion_root="$RESULTS_ROOT/$insertion"
  activity_root="$insertion_root/activity"
  detection_root="$insertion_root/detection"

  echo
  echo "=================================================="
  echo "Insertion : $insertion"
  echo "=================================================="

  CAMPAIGN_NAME="$insertion" \
  START_RUN=101 \
  NUMBER_OF_RUNS=50 \
  TROJAN_VERILOG_FILE="$trojan_file" \
  ACTIVITY_ROOT="$activity_root" \
  VARIANTS=trojan \
  bash "$PAIRED_RUNNER"

  ruby "$SCORER" \
    "$ENVELOPE" \
    "$activity_root/trojan" \
    trojan \
    "$detection_root"

  ruby "$EVALUATOR" \
    "$CLEAN_SCORES" \
    "$detection_root/trojan_run_scores.csv" \
    "$detection_root/detection_metrics.csv"
done

echo
echo "Toutes les insertions ont été évaluées."
echo "Résultats : $RESULTS_ROOT"