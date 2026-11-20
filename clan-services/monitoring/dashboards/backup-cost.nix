# What the backups cost in B2, as queries over what each machine last reported: the backups page shows them, the monitoring tests check them.
let
  # B2's price, read from https://www.backblaze.com/cloud-storage/pricing on 19 Nov 2026: $6.95 per TB stored for 30 days, the account's first 10 GB free.
  dollarsPerTB = "6.95";
  freeBytes = "10e9";

  size = ''restic_repository_size_bytes{job="node"}'';
  # What each machine's repository takes up, as last reported within the 30 days Prometheus keeps, so a laptop that is away still counts.
  stored = "sum by (instance) (last_over_time(${size}[30d]))";
  # Bytes a day each repository grew over the last four weeks, once it has reported for that long: in its first weeks nothing is forgotten yet, and one backup to the next is no trend. One that shrank, as when old snapshots go, counts as not growing.
  growth = "(sum by (instance) (clamp_min(deriv(${size}[28d]), 0)) * 86400 and on (instance) last_over_time(${size}[30d] offset 28d))";
  # Each machine's bytes `days` from now at that pace; none for a machine without one.
  projected = days: "(${stored} + ${growth} * ${toString days})";
  # What B2 charges for 30 days of the machines' `bytes` together.
  bill = bytes: "clamp_min(sum(${bytes}) - ${freeBytes}, 0) * ${dollarsPerTB} / 1e12";
in
{
  inherit
    stored
    growth
    projected
    bill
    ;

  # Each machine's bytes `days` from now, at today's size while it has no growth to go by.
  storedIn = days: "(${projected days} or ${stored})";

  # Each machine's part of the bill for `bytes`: its part of them.
  share = bytes: "${bytes} / scalar(sum(${bytes})) * scalar(${bill bytes})";
}
