#!/usr/bin/env bash
# =====================================================================
# deploy-installer.sh -- deploy the VCF 9.1 Installer appliance OVA.
#
# The VCF Installer is the entry point for the brownfield CONVERGE gate
# (turning an existing standalone vSphere env into your first VCF 9.1
# management domain). Convergence itself is then driven in the Installer
# UI -- see docs/deployment/converge-runbook.md.
#
# By default this script performs a DRY RUN and only prints the ovftool
# command it would execute. Pass --confirm to actually deploy.
# =====================================================================
set -euo pipefail

OVA=""            # path to VCF-Installer-9.1.0.0-*.ova
TARGET=""         # vi://user@vcenter-or-esx/DC/host/... ovftool locator
NAME="vcf-installer"
IP=""; MASK=""; GW=""; DNS=""; NTP=""; FQDN=""
CONFIRM=0

usage() {
  cat <<EOF
Usage: $0 --ova <file> --target <ovftool-locator> --fqdn <fqdn> \\
          --ip <ip> --mask <mask> --gw <gw> --dns <dns> --ntp <ntp> [--name <vm>] [--confirm]

Deploys the VCF 9.1 Installer OVA. Without --confirm, prints the command only.
Password inputs are read from the environment (ovftool prompts, or use
--X:injectOvfEnv style properties as required by your build).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ova) OVA="$2"; shift 2;;
    --target) TARGET="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    --fqdn) FQDN="$2"; shift 2;;
    --ip) IP="$2"; shift 2;;
    --mask) MASK="$2"; shift 2;;
    --gw) GW="$2"; shift 2;;
    --dns) DNS="$2"; shift 2;;
    --ntp) NTP="$2"; shift 2;;
    --confirm) CONFIRM=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

for req in OVA TARGET FQDN IP MASK GW DNS NTP; do
  if [[ -z "${!req}" ]]; then echo "ERROR: --${req,,} is required"; usage; exit 1; fi
done

if [[ "$CONFIRM" -eq 1 ]]; then
  if ! command -v ovftool >/dev/null 2>&1; then
    echo "ERROR: ovftool not found in PATH. Install VMware OVF Tool first."
    exit 1
  fi
  if [[ ! -f "$OVA" ]]; then echo "ERROR: OVA not found: $OVA"; exit 1; fi
fi

# Property names follow the VCF Installer OVF; adjust to match your build's
# OVF environment keys if they differ.
CMD=(ovftool
  --acceptAllEulas --noSSLVerify --powerOn
  --name="$NAME"
  --prop:vami.hostname="$FQDN"
  --prop:vami.ip0.="$IP"
  --prop:vami.netmask0.="$MASK"
  --prop:vami.gateway.="$GW"
  --prop:vami.DNS.="$DNS"
  --prop:ntp.servers="$NTP"
  "$OVA" "$TARGET")

echo "== VCF 9.1 Installer deployment =="
printf '  %q ' "${CMD[@]}"; echo

if [[ "$CONFIRM" -ne 1 ]]; then
  echo
  echo "DRY RUN -- re-run with --confirm to execute the command above."
  exit 0
fi

echo "Deploying..."
"${CMD[@]}"
echo "Done. Open https://$FQDN to continue the converge workflow in the Installer UI."
