# B2 cost queries, shared by the backups page and the tests.
let
  # https://www.backblaze.com/cloud-storage/pricing (19 Nov 2026); 10 GB free per account.
  dollarsPerTB = "6.95";
  freeBytes = "10e9";

  size = ''restic_repository_size_bytes{job="node"}'';
  # Last report within the 30 days Prometheus keeps, so a laptop that's away still counts.
  stored = "sum by (instance) (last_over_time(${size}[30d]))";
  # Bytes/day over 28 days, shrinking as 0; none for newer repos, which aren't pruned yet.
  growth = "(sum by (instance) (clamp_min(deriv(${size}[28d]), 0)) * 86400 and on (instance) last_over_time(${size}[30d] offset 28d))";
  # Bytes `days` from now at that pace.
  projected = days: "(${stored} + ${growth} * ${toString days})";
  # B2's 30-day bill for all machines' `bytes` together.
  bill = bytes: "clamp_min(sum(${bytes}) - ${freeBytes}, 0) * ${dollarsPerTB} / 1e12";
in
{
  inherit
    stored
    growth
    projected
    bill
    ;

  # Like projected, but today's size while there's no growth yet.
  storedIn = days: "(${projected days} or ${stored})";

  # Each machine's share of the bill, by its share of `bytes`.
  share = bytes: "${bytes} / scalar(sum(${bytes})) * scalar(${bill bytes})";
}
