# The backups page's cost queries against what the machines report.
let
  cost = import ../dashboards/backup-cost.nix;

  stored = instance: bytes: {
    series = ''restic_repository_size_bytes{job="node", instance="${instance}", backup="state"}'';
    values = bytes;
  };

  result = expr: eval_time: exp_samples: {
    inherit expr eval_time exp_samples;
  };
in
[
  {
    name = "the free 10 GB come off the account total once, not off each machine";
    interval = "1h";
    input_series = [
      (stored "server" "6000000000x2")
      (stored "laptop" "6000000000x2")
    ];
    promql_expr_test = [
      # 12 GB stored, 2 GB of it paid at $6.95 a TB.
      (result (cost.bill cost.stored) "2h" [ { value = 0.0139; } ])
      (result (cost.share cost.stored) "2h" [
        {
          labels = ''{instance="laptop"}'';
          value = 0.00695;
        }
        {
          labels = ''{instance="server"}'';
          value = 0.00695;
        }
      ])
    ];
  }

  {
    name = "under 10 GB the backups cost nothing";
    interval = "1h";
    input_series = [ (stored "server" "9000000000x2") ];
    promql_expr_test = [ (result (cost.bill cost.stored) "2h" [ { value = 0; } ]) ];
  }

  {
    name = "a laptop away for ten days still counts at its last report";
    interval = "1h";
    input_series = [
      (stored "server" "20000000000x480")
      # It reports for a day, then is away.
      (stored "laptop" "40000000000x24 _x456")
    ];
    promql_expr_test = [ (result (cost.bill cost.stored) "480h" [ { value = 0.3475; } ]) ];
  }

  {
    name = "after 28 days a repository's growth is projected, and shrinking counts as no growth";
    interval = "1d";
    input_series = [
      # Growing by 1 GB a day.
      (stored "laptop" "40000000000+1000000000x28")
      # Shrinking, as when old snapshots go.
      (stored "server" "20000000000-100000000x28")
    ];
    promql_expr_test = [
      (result (cost.storedIn 91) "28d" [
        {
          labels = ''{instance="laptop"}'';
          value = 159000000000;
        }
        {
          labels = ''{instance="server"}'';
          value = 17200000000;
        }
      ])
      # 159 GB and 17.2 GB, less the free 10 GB.
      (result (cost.bill (cost.storedIn 91)) "28d" [ { value = 1.15509; } ])
    ];
  }

  {
    name = "a repository a day old has no growth, and counts at today's size";
    interval = "1h";
    input_series = [ (stored "laptop" "40000000000x24") ];
    promql_expr_test = [
      (result cost.growth "24h" [ ])
      (result (cost.storedIn 91) "24h" [
        {
          labels = ''{instance="laptop"}'';
          value = 40000000000;
        }
      ])
      # 40 GB, less the free 10 GB.
      (result (cost.bill (cost.storedIn 91)) "24h" [ { value = 0.2085; } ])
    ];
  }

  {
    name = "a second backup makes no growth either";
    interval = "1h";
    input_series = [
      # The next day's backup adds a gigabyte.
      (stored "laptop" "40000000000x23 41000000000x3")
    ];
    promql_expr_test = [
      (result cost.growth "26h" [ ])
      (result (cost.projected 365) "26h" [ ])
      (result (cost.storedIn 365) "26h" [
        {
          labels = ''{instance="laptop"}'';
          value = 41000000000;
        }
      ])
    ];
  }
]
