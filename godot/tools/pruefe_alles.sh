#!/usr/bin/env bash
# Feste Prüf-Pipeline: führt alle Tests aus (headless), fasst Ergebnisse zusammen.
# Aufruf: GODOT=/pfad/zu/godot tools/pruefe_alles.sh [Ausgabeordner]
# Rückgabe: 0 = alles grün, 1 = mindestens ein Test schlägt fehl oder hat Skriptfehler.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/einbruch_pruefung}"
mkdir -p "$OUT"
SUMMARY="$OUT/zusammenfassung.txt"
: > "$SUMMARY"
fail=0
total=0
for f in tests/test_*.gd; do
  t=$(basename "$f" .gd)
  total=$((total+1))
  timeout 600 xvfb-run -a "$GODOT" --headless --path . --script "res://tests/$t.gd" > "$OUT/$t.txt" 2>&1
  rc=$?
  fails=$(grep -c '  FAIL' "$OUT/$t.txt")
  errs=$(grep -c 'SCRIPT ERROR\|Parse Error' "$OUT/$t.txt")
  if [ "$rc" -ne 0 ] || [ "$fails" -ne 0 ] || [ "$errs" -ne 0 ]; then
    fail=$((fail+1))
    echo "FEHLER  $t  (rc=$rc, fehlgeschlagen=$fails, Skriptfehler=$errs)" | tee -a "$SUMMARY"
  else
    echo "ok      $t" >> "$SUMMARY"
  fi
done
echo "" | tee -a "$SUMMARY"
echo "Tests: $total · Fehler: $fail · Ausgabe: $OUT" | tee -a "$SUMMARY"
[ "$fail" -eq 0 ]
