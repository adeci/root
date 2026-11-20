# How old each machine's newest snapshot is, as both the backups and the fleet pages show it.
let
  ui = import ./lib.nix;

  # How many of its two ages a machine's newest snapshot has passed by the clock: a server's 36 and 72 hours and a laptop's 3 and 7 days, the ages the fleet's alerts use, though a laptop's alerts count only its time on. `snapshot` reads the newest snapshot's time on one kind of machine.
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

  # The machines `matchers` select, each fresh, old or too old over the time range.
  timeline =
    {
      matchers,
      w,
      h,
    }:
    ui.stateTimeline {
      title = "Fresh";
      description = "How old each machine's newest snapshot is: a server's backup is old after 36 hours and too old after 72, a laptop's after 3 and 7 days.";
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
