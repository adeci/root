{ lib, pkgs }:
let
  yaml = pkgs.formats.yaml { };

  rules = import ../rules.nix {
    inherit lib;
    alwaysOn = [ "server" ];
    machineRules = { };
  };
  rulesFile = yaml.generate "fleet-rules.yml" rules.fleet;

  ruleTests = yaml.generate "fleet-rules-test.yml" {
    rule_files = [ "${rulesFile}" ];
    evaluation_interval = "1m";
    tests = import ./rule-tests.nix;
  };
  # Every 30 minutes: LaptopBackupStale has no `for`, and promtool evaluates all rules at each step of these weeks.
  laptopTests = yaml.generate "laptop-backup-test.yml" {
    rule_files = [ "${rulesFile}" ];
    evaluation_interval = "30m";
    tests = import ./laptop-backup-tests.nix;
  };
  # Queries only, without rules: promtool would evaluate them all each minute these tests span.
  costTests = yaml.generate "backup-cost-test.yml" { tests = import ./backup-cost-tests.nix; };

  alertWithoutSeverity = import ../rules.nix {
    inherit lib;
    alwaysOn = [ ];
    machineRules.server = [
      {
        alert = "Unrouted";
        expr = "vector(1)";
      }
    ];
  };
  rejectsAlertWithoutSeverity =
    !(builtins.tryEval (builtins.deepSeq alertWithoutSeverity.machines.groups null)).success;

  alertmanagerConfig = yaml.generate "alertmanager.yml" (
    import ../alertmanager.nix {
      inherit lib;
      webhookUrl = "http://127.0.0.1:8000/hook";
      timeZone = "America/New_York";
      quietHours = {
        start = "22:00";
        end = "08:00";
      };
    }
  );

  bridgeConfig = yaml.generate "alertmanager-ntfy.yml" (
    import ../ntfy-bridge.nix {
      listenAddress = "127.0.0.1:8000";
      baseUrl = "http://127.0.0.1:8001";
      topic = "alerts";
      clickUrl = "https://grafana.example/d/fleet";
    }
  );
in
assert lib.assertMsg rejectsAlertWithoutSeverity "rules.nix accepts an alert without a severity";
pkgs.runCommand "monitoring-tests"
  {
    nativeBuildInputs = [
      pkgs.alertmanager-ntfy
      pkgs.prometheus-alertmanager
      pkgs.prometheus.cli
      pkgs.python3
    ];
  }
  ''
    promtool test rules ${ruleTests} ${laptopTests} ${costTests}

    amtool config routes test --config.file=${alertmanagerConfig} --verify.receivers=ntfy severity=warning
    amtool config routes test --config.file=${alertmanagerConfig} --verify.receivers=ntfy-once severity=warning send_resolved=false
    # A critical stops at the root route: the routes below it wait out quiet hours.
    amtool config routes test --config.file=${alertmanagerConfig} --tree severity=critical | tee routes
    grep --quiet '^└── default-route  receiver: ntfy$' routes

    python3 ${./ntfy-bridge.py} ${bridgeConfig}

    touch $out
  ''
