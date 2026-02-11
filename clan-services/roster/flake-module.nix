# Roster Service Flake Module
#
# Provides test infrastructure for the roster module.
#
# Run tests with:
#   nix eval .#legacyPackages.x86_64-linux.eval-tests-roster  # View test results
#   nix build .#checks.x86_64-linux.eval-tests-roster         # Run as check
#
{ lib, ... }:
let
  module = import ./default.nix { };
in
{
  perSystem =
    { pkgs, ... }:
    let
      # Evaluate tests at flake eval time (not in derivation)
      testResults = import ./tests/eval-tests.nix { inherit lib module; };

      # Convert test results to a check derivation
      testCheck =
        let
          # Find failing tests
          failures = lib.filterAttrs (_name: test: test.expr != test.expected) testResults;
          failureCount = builtins.length (builtins.attrNames failures);
          totalCount = builtins.length (builtins.attrNames testResults);

          # Format failure messages
          formatFailure = name: test: ''
            FAIL: ${name}
              expected: ${builtins.toJSON test.expected}
              got:      ${builtins.toJSON test.expr}
          '';
          failureMessages = lib.concatStringsSep "\n" (lib.mapAttrsToList formatFailure failures);
        in
        pkgs.runCommand "roster-eval-tests" { } (
          if failureCount == 0 then
            ''
              echo "All ${toString totalCount} tests passed!"
              touch $out
            ''
          else
            ''
              echo "Test failures (${toString failureCount}/${toString totalCount}):"
              echo ""
              cat <<'EOF'
              ${failureMessages}
              EOF
              exit 1
            ''
        );
    in
    {
      # Expose tests for inspection
      legacyPackages.eval-tests-roster = testResults;

      # Check that runs tests
      checks.eval-tests-roster = testCheck;
    };
}
