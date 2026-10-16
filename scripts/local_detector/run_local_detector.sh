#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

CIRCUIT="${CIRCUIT:-c432}"

ACTIVITY_ROOT="${ACTIVITY_ROOT:-$PROJECT_ROOT/results/activity/$CIRCUIT/trojan_campaign}"
CLEAN_ROOT="${CLEAN_ROOT:-$ACTIVITY_ROOT/clean}"
TROJAN_ROOT="${TROJAN_ROOT:-$ACTIVITY_ROOT/trojan}"

OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_ROOT/results/detection/$CIRCUIT/trojan_campaign}"

ENVELOPE="$OUTPUT_ROOT/clean_envelope.json"
CLEAN_RUN_SCORES="$OUTPUT_ROOT/clean_run_scores.csv"
TROJAN_RUN_SCORES="$OUTPUT_ROOT/trojan_run_scores.csv"
METRICS="$OUTPUT_ROOT/detection_metrics.csv"

# Vérifier les dossiers d'entrée
for required_dir in "$CLEAN_ROOT" "$TROJAN_ROOT"; do
  if [[ ! -d "$required_dir" ]]; then
    echo "[ERROR] Dossier d'activité introuvable : $required_dir" >&2
    exit 1
  fi
done

mkdir -p "$OUTPUT_ROOT"

echo "Circuit : $CIRCUIT"
echo "Clean   : $CLEAN_ROOT"
echo "Trojan  : $TROJAN_ROOT"
echo "Sortie  : $OUTPUT_ROOT"
echo

echo "[1/4] Construction de l'enveloppe clean..."
ruby "$SCRIPT_DIR/build_clean_envelope.rb" \
  "$CLEAN_ROOT" \
  "$ENVELOPE"

echo
echo "[2/4] Calcul des scores clean hors apprentissage..."
ruby "$SCRIPT_DIR/score_activity.rb" \
  "$ENVELOPE" \
  "$CLEAN_ROOT" \
  clean \
  "$OUTPUT_ROOT"

echo
echo "[3/4] Calcul des scores Trojan..."
ruby "$SCRIPT_DIR/score_activity.rb" \
  "$ENVELOPE" \
  "$TROJAN_ROOT" \
  trojan \
  "$OUTPUT_ROOT"

echo
echo "[4/4] Évaluation de la détection..."
ruby "$SCRIPT_DIR/evaluate_detector.rb" \
  "$CLEAN_RUN_SCORES" \
  "$TROJAN_RUN_SCORES" \
  "$METRICS"

echo
echo "Traitement terminé."
echo "Enveloppe : $ENVELOPE"
echo "Métriques : $METRICS"
echo "Détails   : $OUTPUT_ROOT"