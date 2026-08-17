#!/usr/bin/env bash
# =====================================================================
# preflight.sh -- read-only readiness checks for the VCF 9.1 brownfield
# framework. Verifies local tooling and (best-effort) DNS/NTP for the
# endpoints declared in the site definition. Makes NO changes.
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_FILE="${SITE_FILE:-$SCRIPT_DIR/../config/site.yaml}"
if [[ ! -f "$SITE_FILE" ]]; then
  SITE_FILE="$SCRIPT_DIR/../config/site.example.yaml"
fi

fail=0
info()  { printf '  [INFO] %s\n' "$*"; }
ok()    { printf '  [ OK ] %s\n' "$*"; }
warn()  { printf '  [WARN] %s\n' "$*"; }
err()   { printf '  [FAIL] %s\n' "$*"; fail=1; }

echo "== Tooling =="
for t in terraform; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t: $($t version 2>/dev/null | head -1)"; else err "$t not found in PATH"; fi
done
for t in dig nc; do
  command -v "$t" >/dev/null 2>&1 && ok "$t available" || warn "$t not found (DNS/NTP checks limited)"
done

echo "== Site definition =="
info "Using $SITE_FILE"

# Extract endpoint FQDNs from host/fqdn/vip_fqdn keys (best effort, no YAML dep).
# Excludes the example domain and non-DNS suffixes (.local SSO, file names).
mapfile -t FQDNS < <(grep -Ei '(host|fqdn):' "$SITE_FILE" \
  | grep -Eo '([a-z0-9-]+\.)+[a-z]{2,}' \
  | grep -Ev '(example\.com|\.local|\.yaml|\.sh|\.md|\.tf|\.hcl)$' \
  | sort -u || true)
if [[ ${#FQDNS[@]} -eq 0 ]]; then
  warn "No non-example FQDNs found in site file (still using example values?)"
fi

echo "== DNS forward/reverse =="
if command -v dig >/dev/null 2>&1; then
  for fqdn in "${FQDNS[@]}"; do
    ip="$(dig +short "$fqdn" A | head -1 || true)"
    if [[ -n "$ip" ]]; then
      ptr="$(dig +short -x "$ip" | head -1 || true)"
      if [[ -n "$ptr" ]]; then ok "$fqdn -> $ip -> $ptr"; else err "$fqdn -> $ip but NO PTR record (VCF requires forward+reverse DNS)"; fi
    else
      err "$fqdn has no A record"
    fi
  done
else
  warn "dig not available; skipping DNS validation"
fi

echo "== NTP reachability (udp/123) =="
if command -v nc >/dev/null 2>&1; then
  mapfile -t NTPS < <(awk '/ntp_servers:/{f=1;next} f&&/^ *- /{gsub(/[- ]/,"");print} f&&!/^ *- /{f=0}' "$SITE_FILE" || true)
  for ntp in "${NTPS[@]:-}"; do
    [[ -z "$ntp" ]] && continue
    if nc -u -z -w2 "$ntp" 123 >/dev/null 2>&1; then ok "NTP $ntp reachable"; else warn "NTP $ntp not reachable (udp/123)"; fi
  done
else
  warn "nc not available; skipping NTP validation"
fi

echo
if [[ "$fail" -ne 0 ]]; then
  echo "Preflight FAILED -- resolve the [FAIL] items above before deploying."
  exit 1
fi
echo "Preflight checks passed (warnings, if any, are advisory)."
