# One-shot provisioning for MikroTik cAP ax (ARM64, WiFi 6).
# Netinstalls RouterOS + wifi-qcom, sets admin password, adds DHCP client.
# Device goes from factory/blank to terraform-ready in one command.
#
# Usage: nix run .#routeros-netinstall-cap-ax
#
# Prerequisites:
#   - Device in Netinstall mode (hold reset 15s: flash → solid → off → release)
#   - This machine connected to device ether1 via ethernet
{ pkgs, clan-cli }:
let
  version = "7.22.1";
  arch = "arm64";

  netinstall-cli = pkgs.stdenvNoCC.mkDerivation {
    pname = "netinstall-cli";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://download.mikrotik.com/routeros/${version}/netinstall-${version}.tar.gz";
      hash = "sha256-qy+4b4X7p4nICpeD12PpjrsWtdeFjQDSAip8Unj2zbU=";
    };
    sourceRoot = ".";
    dontBuild = true;
    installPhase = "install -Dm755 netinstall-cli $out/bin/netinstall-cli";
  };

  routeros = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/routeros-${version}-${arch}.npk";
    hash = "sha256-pfyYQKeoeDLYHpaZzqga6Wmz2SSEegtFNpdOWlibIGc=";
  };

  wifi-qcom = pkgs.fetchurl {
    url = "https://download.mikrotik.com/routeros/${version}/wifi-qcom-${version}-${arch}.npk";
    hash = "sha256-6npDjebffBOnASLOiAWNjCyppdGdsAPd20HDjs6+dZU=";
  };
in
pkgs.writeShellApplication {
  name = "routeros-netinstall-cap-ax";
  runtimeInputs = [
    pkgs.iproute2
    pkgs.iptables
    pkgs.jq
    clan-cli
  ];
  text = # bash
    ''
      echo "RouterOS Netinstall — cAP ax (${arch}, v${version})"
      echo ""
      echo "Prerequisites:"
      echo "  1. Device in Netinstall mode (hold reset 15s: flash → solid → off → release)"
      echo "  2. This machine connected to device ether1 via ethernet"
      echo ""

      # ── Pick interface ───────────────────────────────────────────
      mapfile -t ifaces < <(ip -j link show | jq -r '.[] | select(.ifname | startswith("en") or startswith("eth")) | "\(.ifname) \(.operstate)"')

      if [[ ''${#ifaces[@]} -eq 0 ]]; then
        echo "ERROR: No ethernet interfaces found."
        exit 1
      fi

      echo "Select the interface connected to the device:"
      echo ""
      for i in "''${!ifaces[@]}"; do
        read -r name state <<< "''${ifaces[$i]}"
        printf "  %d) %-20s [%s]\n" "$((i + 1))" "$name" "$state"
      done
      echo ""
      read -rp "Enter number: " choice
      choice=$((choice - 1))

      if [[ $choice -lt 0 || $choice -ge ''${#ifaces[@]} ]]; then
        echo "ERROR: Invalid selection."
        exit 1
      fi
      read -r iface _ <<< "''${ifaces[$choice]}"

      # ── Setup network ────────────────────────────────────────────
      echo ""
      echo "==> Setting up 192.168.88.2/24 on $iface..."
      sudo ip addr replace 192.168.88.2/24 dev "$iface"
      sudo ip link set "$iface" up

      cleanup() {
        echo "==> Cleaning up..."
        sudo iptables -D nixos-fw -i "$iface" -j ACCEPT 2>/dev/null || true
        sudo ip addr del 192.168.88.2/24 dev "$iface" 2>/dev/null || true
        rm -f "$setup_script"
      }
      trap cleanup EXIT

      # ── Open firewall ──────────────────────────────────────────────
      echo "==> Opening firewall on $iface (temporary)..."
      sudo iptables -I nixos-fw 3 -i "$iface" -j ACCEPT

      # ── Generate setup script ────────────────────────────────────
      echo "==> Reading admin password from clan secrets..."
      password=$(clan secrets get routeros-password)

      setup_script=$(mktemp /tmp/routeros-setup-XXXXXX.rsc)
      cat > "$setup_script" << SETUP
      /user set admin password="$password"
      /ip dhcp-client add interface=ether1 disabled=no
      SETUP

      # ── Run netinstall ───────────────────────────────────────────
      echo "==> Running netinstall..."
      echo "    Packages: routeros-${version}-${arch}.npk, wifi-qcom-${version}-${arch}.npk"
      echo ""
      echo "    Waiting for device in Netinstall mode..."
      echo ""

      sudo ${netinstall-cli}/bin/netinstall-cli \
        -s "$setup_script" \
        -i "$iface" \
        -a 192.168.88.3 \
        "${routeros}" "${wifi-qcom}"

      echo ""
      echo "========================================================"
      echo "  Netinstall complete! (cAP ax, v${version})"
      echo "========================================================"
      echo ""
      echo "  Device has been configured with:"
      echo "    - RouterOS ${version} (${arch}) + wifi-qcom"
      echo "    - Admin password (from clan secrets)"
      echo "    - DHCP client on ether1"
      echo ""
      echo "  Plug ether1 into management network, then net-apply."
      echo ""
    '';
  meta.platforms = pkgs.lib.platforms.linux;
}
