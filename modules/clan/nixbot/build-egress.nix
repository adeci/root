# Fixed-output builds share the host network; keep CI code off loopback, the
# LAN and the tailnet. DNS stays open for fetchers.
{
  networking.firewall.extraCommands = ''
    ip46tables -N nixbld-egress 2>/dev/null || ip46tables -F nixbld-egress
    ip46tables -D OUTPUT -m owner --gid-owner nixbld -j nixbld-egress 2>/dev/null || true
    ip46tables -I OUTPUT -m owner --gid-owner nixbld -j nixbld-egress
    ip46tables -A nixbld-egress -p udp --dport 53 -j RETURN
    ip46tables -A nixbld-egress -p tcp --dport 53 -j RETURN
    for net in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16; do
      iptables -w -A nixbld-egress -d "$net" -j REJECT
    done
    for net in ::1/128 fc00::/7 fe80::/10; do
      ip6tables -w -A nixbld-egress -d "$net" -j REJECT
    done
  '';

  networking.firewall.extraStopCommands = ''
    ip46tables -D OUTPUT -m owner --gid-owner nixbld -j nixbld-egress 2>/dev/null || true
    ip46tables -F nixbld-egress 2>/dev/null || true
    ip46tables -X nixbld-egress 2>/dev/null || true
  '';
}
