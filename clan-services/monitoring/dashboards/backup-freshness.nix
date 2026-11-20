# Snapshot age, shared by the backups and fleet pages.
let
  ui = import ./lib.nix;

  # 0-2 ages passed by the clock, as in the alerts, though laptop alerts count time on only.
  staleness =
    snapshot:
    let
      passed =
        kind: old: tooOld:
        "(time() - ${snapshot kind} > bool ${old}) + (time() - ${snapshot kind} > bool ${tooOld})";
    in
    "max by (instance) ((${passed "server" "36 * 3600" "72 * 3600"}) or (${
      passed "laptop" "3 * 86400" "7 * 86400"
    }))";
in
{
  inherit staleness;

  # Fresh, old or too old over the time range, for the machines `matchers` select.
  timeline =
    {
      matchers,
      w,
      h,
    }:
    ui.stateTimeline {
      title = "Fresh";
      description = "Age of each machine's newest snapshot. A server's backup is old after 36 hours and too old after 72, a laptop's after 3 and 7 days.";
      inherit w h;
      targets = [
        (ui.target (staleness (
          kind: ''restic_snapshot_timestamp_seconds{${matchers}, kind="${kind}"}''
        )) "{{instance}}")
      ];
      threshold = ui.thresholds.goodWhenZero;
      valueMappings = ui.mappings.backupAge;
    };
}
