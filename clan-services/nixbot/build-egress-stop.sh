# shellcheck shell=bash
# ip46tables comes from the NixOS firewall script.
ip46tables -D OUTPUT -m owner --gid-owner nixbld -j nixbld-egress 2>/dev/null || true
ip46tables -F nixbld-egress 2>/dev/null || true
ip46tables -X nixbld-egress 2>/dev/null || true
