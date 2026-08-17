#!/usr/bin/env bash
# =====================================================================
# thumbprints.sh -- read-only helper to collect SSL (and SSH) thumbprints
# for ESX hosts and appliances, used when commissioning hosts or trusting
# certificates during converge/import. Makes NO changes.
#
# Usage:
#   ./thumbprints.sh esxi-11.vcf.example.com esxi-12.vcf.example.com
#   ./thumbprints.sh --ssh esxi-11.vcf.example.com
# =====================================================================
set -euo pipefail

MODE="ssl"
if [[ "${1:-}" == "--ssh" ]]; then MODE="ssh"; shift; fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [--ssh] <host> [host...]"
  exit 1
fi

for host in "$@"; do
  echo "== $host =="
  if [[ "$MODE" == "ssl" ]]; then
    if command -v openssl >/dev/null 2>&1; then
      echo -n "  SHA-256 SSL: "
      echo | openssl s_client -connect "${host}:443" -servername "$host" 2>/dev/null \
        | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
        | sed 's/^.*=//' || echo "(unreachable)"
    else
      echo "  openssl not found"
    fi
  else
    if command -v ssh-keyscan >/dev/null 2>&1; then
      echo "  SSH host keys:"
      ssh-keyscan -T 5 "$host" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | sed 's/^/    /' || echo "    (unreachable)"
    else
      echo "  ssh-keyscan not found"
    fi
  fi
done
