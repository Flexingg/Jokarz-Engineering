#!/usr/bin/env bash
# Acceptance check for the AOR Engineering de-brand: fails if the old app
# name ("jokarz", any case) shows up in source outside the documented
# allow-list below. Run from anywhere; paths are resolved relative to the
# repo root.
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

scopes=(lib android/app/src windows pubspec.yaml)

# Each entry is "path-regex:::content-regex" (extended regex, matched with
# grep -E). A hit is allowed if the file path matches path-regex AND the
# matched line's text matches content-regex.
#
# These are all either the one deliberate remaining mention (settings
# footer) or internal identifiers/infrastructure that item 3 of the
# de-brand task explicitly says to leave alone (Firebase project IDs,
# Android applicationId/namespace/package path, the pubspec package name,
# internal storage cache-file keys) plus the direct build-system analogues
# of those same identifiers on Windows (CMake target/project name, and the
# PE resource fields that mirror it: CompanyName/InternalName/
# OriginalFilename) and the Dart class name in main.dart, none of which are
# strings a user ever sees.
allow=(
  "lib/firebase_options\.dart:::.*"
  "lib/main\.dart:::JokarzEngineeringApp"
  "lib/services/storage_service\.dart:::jokarz_"
  "lib/services/bamm_service\.dart:::jokarz_"
  "android/app/build\.gradle\.kts:::jokarz_engineering"
  "android/app/src/main/kotlin/com/example/jokarz_engineering/.*:::com\.example\.jokarz_engineering"
  "windows/CMakeLists\.txt:::jokarz_engineering"
  "windows/runner/Runner\.rc:::(CompanyName|InternalName|OriginalFilename)"
  "pubspec\.yaml:::name:"
  "tool/check_branding\.sh:::.*"
)

is_allowed() {
  local file="$1" text="$2" entry path_re content_re
  for entry in "${allow[@]}"; do
    path_re="${entry%%:::*}"
    content_re="${entry#*:::}"
    if [[ "$file" =~ ^${path_re}$ ]] && [[ "$text" =~ $content_re ]]; then
      return 0
    fi
  done
  return 1
}

offenses=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  text="${rest#*:}"
  if ! is_allowed "$file" "$text"; then
    echo "$line"
    offenses=$((offenses + 1))
  fi
done < <(grep -rniI -n "jokarz" "${scopes[@]}" 2>/dev/null)

echo
if [[ $offenses -eq 0 ]]; then
  echo "PASS: no un-allow-listed 'jokarz' occurrences found."
  exit 0
else
  echo "FAIL: $offenses un-allow-listed 'jokarz' occurrence(s) found (see above)."
  exit 1
fi
