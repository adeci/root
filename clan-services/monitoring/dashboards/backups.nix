# The machines the agents run on, each as { os, kind, backsUp }.
machines:
let
  ui = import ./lib.nix;
  cost = import ./backup-cost.nix;
  freshness = import ./backup-freshness.nix;

  node = ''job="node"'';
  machineCount = builtins.length (builtins.attrNames machines);
  # The machines the inventory backs up.
  clients = builtins.filter (name: machines.${name}.backsUp) (builtins.attrNames machines);

  # A machine's reading as it last reported it within the 30 days Prometheus keeps, so a laptop that is asleep or away keeps its row.
  latest = aggregation: selector: "${aggregation} by (instance) (last_over_time(${selector}[30d]))";
  newestSnapshot = latest "max" "restic_snapshot_timestamp_seconds{${node}}";

  # A month's bill in 3 or 12 months.
  projectedCost =
    { title, expr }:
    ui.stat {
      inherit title expr;
      description = "What a month would cost then if each repository keeps growing as it did over the last four weeks, as the table below shows; Prometheus keeps 30 days, so no trend is older. A repository that has reported for less than 28 days counts at today's size: in its first weeks nothing is forgotten yet, and one backup to the next is no trend. One that shrank, as when old snapshots go, counts as not growing.";
      w = 6;
      h = 4;
      unit = "currencyUSD";
      decimals = 2;
      threshold = ui.thresholds.plain;
    };
in
ui.dashboard {
  uid = "backups";
  title = "Backups";
  # The whole history Prometheus keeps.
  from = "now-30d";
  panels = [
    (ui.row {
      title = "Which machines back up";
      collapsed = false;
      panels = [
        (ui.mergedTable {
          title = "Machines";
          description = "Every machine of the fleet. Backed up: yes; none yet for a machine the inventory backs up that has taken no snapshot, or not reported one since it was set up; or no. Fresh judges the newest snapshot by the clock: a server's is old after 36 hours and too old after 72, a laptop's after 3 and 7 days. Took is how long the newest snapshot took, and Last run whether the last try failed. Checked is when the machine last read its repository, which it does every hour while it is on.";
          w = 13;
          # A grid unit per machine, plus the title and the header.
          h = machineCount + 2;
          sortBy = [
            {
              displayName = "Backed up";
              desc = true;
            }
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns.instance = "Host";
          columns = [
            {
              name = "Backed up";
              # Room for the sort arrow beside the name.
              width = 110;
              # 2 with a snapshot, 1 for one the inventory backs up, 0 for the rest.
              expr = ''(${newestSnapshot} > bool 0) + 1 or group by (instance) (up{${node}, instance=~"${builtins.concatStringsSep "|" clients}"}) or 0 * group by (instance) (up{${node}})'';
              colours = ui.mappings.backedUp;
            }
            {
              name = "Fresh";
              width = 80;
              expr = "${
                freshness.staleness (
                  kind: ''last_over_time(restic_snapshot_timestamp_seconds{${node}, kind="${kind}"}[30d])''
                )
              } and ${newestSnapshot} > 0";
              colours = ui.mappings.backupAge;
            }
            {
              name = "Last snapshot";
              expr = "1000 * (${newestSnapshot} > 0)";
              unit = "dateTimeFromNow";
            }
            {
              name = "Took";
              width = 80;
              expr = latest "max" "restic_snapshot_duration_seconds{${node}}";
              unit = "s";
              decimals = 0;
            }
            {
              name = "Last run";
              width = 80;
              # 1 unless the backup's unit is in the failed state.
              expr = "1 - ${latest "max" ''node_systemd_unit_state{${node}, name=~"restic-backups-.+[.]service", state="failed"}''}";
              threshold = ui.thresholds.goodWhenOne;
              valueMappings = ui.mappings.passed;
            }
            {
              name = "Checked";
              expr = "1000 * ${latest "max" ''node_textfile_mtime_seconds{${node}, file=~".*/restic-snapshot-.+[.]prom"}''}";
              unit = "dateTimeFromNow";
            }
          ];
        })
        (freshness.timeline {
          matchers = node;
          w = 11;
          h = machineCount + 2;
        })
      ];
    })

    (ui.row {
      title = "What is stored, and for how long";
      collapsed = false;
      panels = [
        (ui.text {
          title = "Kept";
          w = 24;
          h = 3;
          # The numbers of the restic service's default pruneOpts, which the inventory keeps.
          content = "Each machine keeps the newest snapshot of each of the last **14 days**, **8 weeks**, **12 months** and **3 years**, all its snapshots counted as one history: 30 or so once it has backed up for a year. A month's last snapshot stays until that month comes round again, and the oldest reach back up to three years.";
        })
        (ui.mergedTable {
          title = "Repositories";
          description = "Each machine's repository in B2, as the machine last read it. Newest size is what the newest snapshot holds, before deduplication and compression; Stored, what all the snapshots take up in B2. Added is what the snapshots of the last 7 days added, which a laptop that is away cannot tell.";
          w = 24;
          # Eight backups today, plus the title and the header.
          h = 10;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns.instance = "Host";
          columns = [
            {
              name = "Snapshots";
              expr = latest "sum" "restic_snapshots{${node}}";
            }
            {
              name = "Oldest";
              expr = "1000 * ${latest "min" "restic_oldest_snapshot_timestamp_seconds{${node}}"}";
              unit = "dateTimeFromNow";
            }
            {
              name = "Newest";
              expr = "1000 * (${newestSnapshot} > 0)";
              unit = "dateTimeFromNow";
            }
            {
              name = "Newest size";
              expr = latest "sum" "restic_snapshot_size_bytes{${node}}";
              unit = "decbytes";
            }
            {
              name = "Stored";
              expr = cost.stored;
              unit = "decbytes";
            }
            {
              name = "Added in 7 days";
              expr = "sum by (instance) (restic_week_added_bytes{${node}})";
              unit = "decbytes";
            }
          ];
        })
        (ui.mergedTable {
          title = "Folders";
          description = "What each backup holds: the folders of every state its machine declares.";
          w = 15;
          # Twenty folders today, plus the title and the header.
          h = 22;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns = {
            instance = "Host";
            folder = "Folder";
          };
          firstColumns = [
            "instance"
            "folder"
          ];
          labelColumns.Host.width = 110;
          columns = [
            {
              name = "Holds";
              hidden = true;
              expr = "max by (instance, folder) (last_over_time(restic_backup_folder_info{${node}}[30d]))";
            }
          ];
        })
        (ui.mergedTable {
          title = "Left out";
          description = "What the backups leave out of their folders, as their exclude lists give it.";
          w = 9;
          h = 22;
          sortBy = [
            {
              displayName = "Pattern";
              desc = false;
            }
          ];
          renamedColumns.pattern = "Pattern";
          columns = [
            {
              name = "Leaves out";
              hidden = true;
              expr = "group by (pattern) (last_over_time(restic_backup_exclude_info{${node}}[30d]))";
            }
          ];
        })
      ];
    })

    (ui.row {
      title = "What it costs";
      collapsed = false;
      panels = [
        (ui.stat {
          title = "Stored";
          description = "What the backups take up in B2: restic's count of the data their snapshots use, deduplicated and compressed. B2 bills a little more: what a prune leaves unused, up to 5 % of a repository, restic's index, and for a week after a prune the hidden copies of what it removed, sequoia's first thinning included.";
          w = 6;
          h = 4;
          expr = "sum(${cost.stored})";
          unit = "decbytes";
          threshold = ui.thresholds.plain;
        })
        (ui.stat {
          title = "Per month now";
          description = "At B2's price of $6.95 per TB for 30 days. The first 10 GB are free once for the whole account, which also holds Zipline's shares and the Terraform state, not counted here.";
          w = 6;
          h = 4;
          expr = cost.bill cost.stored;
          unit = "currencyUSD";
          decimals = 2;
          threshold = ui.thresholds.plain;
        })
        (projectedCost {
          title = "Per month in 3 months";
          expr = cost.bill (cost.storedIn 91);
        })
        (projectedCost {
          title = "Per month in 12 months";
          expr = cost.bill (cost.storedIn 365);
        })
        (ui.mergedTable {
          title = "By machine";
          description = "Each machine's part of the monthly bill, by its part of what is stored. Growth is over the last four weeks, a repository that shrank counting as not growing, and the last two columns carry it on for 12 months. They stay empty until a machine has reported for 28 days, as its first weeks overstate its growth; the bills above count it at today's size until then.";
          w = 12;
          # Eight backups today, plus the title and the header.
          h = 10;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns.instance = "Host";
          columns = [
            {
              name = "Per month";
              expr = cost.share cost.stored;
              unit = "currencyUSD";
              decimals = 2;
            }
            {
              name = "Growth a week";
              expr = "${cost.growth} * 7";
              unit = "decbytes";
            }
            {
              name = "In 12 months";
              expr = cost.projected 365;
              unit = "decbytes";
            }
            {
              name = "Per month then";
              expr = "${cost.share (cost.storedIn 365)} and on (instance) ${cost.growth}";
              unit = "currencyUSD";
              decimals = 2;
            }
          ];
        })
        (ui.timeseries {
          title = "Stored";
          w = 12;
          h = 10;
          unit = "decbytes";
          # A bar a day, each machine's part stacked on the others', so a bar's height is the total.
          stackedBars = true;
          interval = "1d";
          overrides = ui.coloursByName clients;
          targets = [
            (ui.target "sum by (instance) (last_over_time(restic_repository_size_bytes{${node}}[1d]))" "{{instance}}")
          ];
        })
      ];
    })
  ];
}
