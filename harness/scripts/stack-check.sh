#!/usr/bin/env bash
# Checks the release lines of the stack against endoflife.date (decision 0021,
# harness/policies/versions.md). Part of the gate `make deps`.
#
# Usage: stack-check.sh [--root <dir>] [--config <file>] [--data-dir <dir>] [--today YYYY-MM-DD]
#        stack-check.sh --latest <product> [--data-dir <dir>] [--today YYYY-MM-DD]
#
# Reads the list `stack` of harness/config.yml. One entry per runtime, language, framework,
# database and base image: "<product> <line>" or "<product> <line> adr:<NNNN>", with the product
# and line names of https://endoflife.date.
# Blocking: a line without support (an ADR does not lift this); a newer LTS line that is LTS for
# at least stack_lts_grace_days days (default 30) and has no ADR; a line that is not LTS while the
# product has LTS lines and the entry has no ADR; an ADR that docs/adr/ does not have; an empty
# list in a repository with a dependency manifest.
# Notes: support that ends within 90 days, a newer LTS line inside the grace period or with an
# ADR, a newer line of a product without LTS lines.
# --latest prints the line a new stack decision takes: the newest LTS line, or the newest
# supported line when the product has no LTS lines, then the other supported lines.
# --data-dir reads <dir>/<product>.json instead of the network (tests).
# Exit 0: no blocking finding. Exit 1: a blocking finding or no data. Exit 2: usage or config error.
set -euo pipefail

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

API="https://endoflife.date/api/v1/products"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CONFIG=""
DATA_DIR=""
TODAY=""
LATEST=""
SOON_DAYS=90

need() { if [ $# -lt 2 ] || [ "${2#--}" != "$2" ]; then echo "$1 needs a value" >&2; usage >&2; exit 2; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --root) need "$@"; ROOT=$(cd "$2" && pwd); shift 2 ;;
    --config) need "$@"; CONFIG="$2"; shift 2 ;;
    --data-dir) need "$@"; DATA_DIR="$2"; shift 2 ;;
    --today) need "$@"; TODAY="$2"; shift 2 ;;
    --latest) need "$@"; LATEST="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$CONFIG" ] || CONFIG="$ROOT/harness/config.yml"
[ -n "$TODAY" ] || TODAY=$(date -u +%Y-%m-%d)
if ! [[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then echo "--today is not a date: $TODAY" >&2; exit 2; fi
command -v jq >/dev/null 2>&1 || { echo "stack-check: jq is required" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

FETCH=""
fetch() {
  local product="$1" out="$2" code
  FETCH="unreachable"
  if [ -n "$DATA_DIR" ]; then
    if [ -f "$DATA_DIR/$product.json" ]; then cp "$DATA_DIR/$product.json" "$out"; else FETCH="unknown"; return 0; fi
  else
    code=$(curl -sSL --retry 2 --max-time 20 -o "$out" -w '%{http_code}' "$API/$product" 2>/dev/null) || code=000
    if [ "$code" = 404 ]; then FETCH="unknown"; return 0; fi
    [ "$code" = 200 ] || return 0
  fi
  if jq -e '.result.releases | type == "array"' "$out" >/dev/null 2>&1; then FETCH="ok"; fi
}

read -r -d '' JQ_DEFS <<'JQ' || true
def isdate: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
def ts: . + "T00:00:00Z" | fromdateiso8601;
def day: strftime("%Y-%m-%d");
def released($now): (.releaseDate | isdate) and ((.releaseDate | ts) <= $now);
def lts_start: if (.ltsFrom | isdate) then .ltsFrom else .releaseDate end;
def lts($now): released($now) and (if (.ltsFrom | isdate) then (.ltsFrom | ts) <= $now else .isLts == true end);
def newest: sort_by(.releaseDate) | last;
JQ

read -r -d '' JQ_CHECK <<'JQ' || true
($today | ts) as $now
| .result.releases as $all
| ($all | map(select(.name == $line)) | first) as $cur
| if $cur == null then
    ["config", "Linie \($line) nicht gefunden. Linien bei endoflife.date: \($all[:10] | map(.name) | join(", "))"]
  else
    ($all | map(select(lts($now)))) as $lts
    | (if $cur.isEol == true then
         ["block", "ohne Support seit \($cur.eolFrom // "unbekannt")"]
       elif ($cur.eolFrom | isdate) and ((($cur.eolFrom | ts) - $now) <= ($soon * 86400)) then
         ["note", "Support endet am \($cur.eolFrom)"]
       else empty end),
      (if ($lts | length) > 0 then
         ($lts | map(select(.releaseDate > ($cur.releaseDate // ""))) | newest) as $new
         | if ($cur | lts($now) | not) then
             ($lts | newest) as $best
             | if $adr != "" then
                 ["note", "keine LTS-Linie (neueste LTS-Linie: \($best.name)); begründet in ADR \($adr)"]
               else
                 ["block", "keine LTS-Linie; die neueste LTS-Linie ist \($best.name)"]
               end
           elif $new != null then
             ($new | lts_start) as $start
             | (($start | ts) + ($grace * 86400)) as $deadline
             | if $adr != "" then
                 ["note", "neuere LTS-Linie \($new.name), LTS seit \($start); die ältere Linie begründet ADR \($adr)"]
               elif $now >= $deadline then
                 ["block", "neuere LTS-Linie \($new.name), LTS seit \($start)"]
               else
                 ["note", "neuere LTS-Linie \($new.name), LTS seit \($start); blockiert ab \($deadline | day)"]
               end
           else empty end
       else
         ($all | map(select(released($now) and .isEol != true and .releaseDate > ($cur.releaseDate // ""))) | newest) as $new
         | if $new != null then
             ["note", "neuere Linie \($new.name) seit \($new.releaseDate) (Produkt ohne LTS-Linien)"]
           else empty end
       end)
  end
| @tsv
JQ

read -r -d '' JQ_LATEST <<'JQ' || true
($today | ts) as $now
| .result.releases as $all
| ($all | map(select(lts($now)))) as $lts
| ($all | map(select(released($now) and .isEol != true))) as $supported
| (if ($lts | length) > 0 then ($lts | newest) else ($supported | newest) end) as $pick
| if $pick == null then empty else
    "\($product) \($pick.name)\t"
    + (if ($lts | length) > 0 then "LTS seit \($pick | lts_start)" else "keine LTS-Linien, erschienen \($pick.releaseDate)" end)
    + ", Support bis \($pick.eolFrom // "offen"), neueste Version \($pick.latest.name // "unbekannt")",
    ($supported | sort_by(.releaseDate) | reverse | .[] | select(.name != $pick.name)
     | "  weitere Linie mit Support: \(.name)" + (if lts($now) then " (LTS)" else "" end) + ", Support bis \(.eolFrom // "offen")")
  end
JQ

valid_product() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; }

if [ -n "$LATEST" ]; then
  valid_product "$LATEST" || { echo "stack-check: kein Produktname von endoflife.date: $LATEST" >&2; exit 2; }
  fetch "$LATEST" "$TMP/latest.json"
  case "$FETCH" in
    unknown) echo "stack-check: $LATEST ist bei endoflife.date nicht bekannt (https://endoflife.date)." >&2; exit 2 ;;
    unreachable) echo "stack-check: keine Daten für $LATEST von endoflife.date." >&2; exit 1 ;;
  esac
  out=$(jq -r --arg product "$LATEST" --arg today "$TODAY" "$JQ_DEFS $JQ_LATEST" "$TMP/latest.json")
  [ -n "$out" ] || { echo "stack-check: $LATEST hat keine Linie mit Support." >&2; exit 1; }
  printf '%s\n' "$out"
  exit 0
fi

entries=""
grace=30
if [ -f "$CONFIG" ]; then
  entries=$(awk '
    /^stack:/ { f = 1; next }
    f && /^[ \t]*-/ { sub(/^[ \t]*-[ \t]*/, ""); gsub(/"/, ""); sub(/[ \t]+#.*$/, ""); sub(/[ \t]+$/, ""); print; next }
    f && /^[ \t]*(#.*)?$/ { next }
    f { exit }' "$CONFIG")
  g=$(awk '$1 == "stack_lts_grace_days:" { v = $2; gsub(/"/, "", v); print "=" v; exit }' "$CONFIG")
  if [ -n "$g" ]; then grace=${g#=}; fi
fi
if ! [[ "$grace" =~ ^[0-9]+$ ]]; then echo "stack: stack_lts_grace_days ist keine Zahl: $grace" >&2; exit 2; fi

if [ -z "$entries" ]; then
  manifest=$(find "$ROOT" -maxdepth 3 \( -name node_modules -o -name .git -o -name target -o -name vendor \) -prune -o -type f \
    \( -name package.json -o -name pom.xml -o -name 'build.gradle*' -o -name go.mod -o -name '*.csproj' -o -name pyproject.toml \
    -o -name 'requirements*.txt' -o -name Cargo.toml -o -name Gemfile -o -name composer.json \) -print 2>/dev/null | head -1)
  if [ -n "$manifest" ]; then
    echo "stack: die Liste stack in harness/config.yml ist leer, das Repository hat aber ${manifest#"$ROOT"/}." >&2
    echo "Jede Laufzeit, Sprache, jedes Framework, jede Datenbank und jedes Basis-Image eintragen (harness/policies/versions.md)." >&2
    exit 1
  fi
  echo "stack: keine Einträge in stack (harness/config.yml) und kein Manifest, nichts zu prüfen."
  exit 0
fi

status=0
config_error=0
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  product="" line="" adr="" rest=""
  read -r product line adr rest <<< "$entry"
  if ! valid_product "$product" || ! [[ "$line" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [ -n "$rest" ] || { [ -n "$adr" ] && ! [[ "$adr" =~ ^adr:[0-9]{4}$ ]]; }; then
    echo "stack: Eintrag nicht lesbar: \"$entry\". Form: \"<produkt> <linie>\" oder \"<produkt> <linie> adr:<NNNN>\"." >&2
    config_error=1
    continue
  fi
  adr=${adr#adr:}
  fetch "$product" "$TMP/product.json"
  case "$FETCH" in
    unknown)
      echo "stack: $product ist bei endoflife.date nicht bekannt. Produktnamen: https://endoflife.date" >&2
      config_error=1
      continue ;;
    unreachable)
      echo "stack: $product $line: keine Daten von endoflife.date; der Lauf zählt als nicht bestanden. Erneut starten." >&2
      status=1
      continue ;;
  esac
  if [ -n "$adr" ] && ! compgen -G "$ROOT/docs/adr/$adr-*.md" >/dev/null; then
    echo "stack: $product $line: ADR $adr fehlt in docs/adr/." >&2
    status=1
  fi
  findings=$(jq -r --arg line "$line" --arg adr "$adr" --arg today "$TODAY" --argjson grace "$grace" --argjson soon "$SOON_DAYS" \
    "$JQ_DEFS $JQ_CHECK" "$TMP/product.json") || { echo "stack: $product $line: Daten von endoflife.date nicht lesbar." >&2; status=1; continue; }
  while IFS=$'\t' read -r kind text; do
    [ -n "$kind" ] || continue
    case "$kind" in
      config) echo "stack: $product: $text" >&2; config_error=1 ;;
      block) echo "stack: $product $line: $text" >&2; status=1 ;;
      *) echo "stack: $product $line: $text (Hinweis)" ;;
    esac
  done <<< "$findings"
done <<< "$entries"

if [ "$status" -ne 0 ]; then
  echo "Regel: harness/policies/versions.md. Das Upgrade ist eine eigene Spec; eine ältere LTS-Linie braucht ein ADR mit Begründung und adr:<NNNN> am Eintrag. Eine Linie ohne Support braucht das Upgrade." >&2
fi
if [ "$config_error" -ne 0 ]; then exit 2; fi
exit "$status"
