# shellcheck shell=bash
cd "$(git rev-parse --show-toplevel)" || exit
mkdir -p ".terraform/$WORKSPACE"
cd ".terraform/$WORKSPACE" || exit

AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
# B2 rejects the checksums newer AWS SDKs send by default.
AWS_REQUEST_CHECKSUM_CALCULATION=when_required
AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

install -m644 "$WORKSPACE_CONFIG" config.tf.json

# tofu's lock file records the last init's provider versions and checksums, so init would fail once Nix moves a version, and keep the old build when Nix only rebuilds one.
rm -f .terraform.lock.hcl

# tofu won't run once the config's providers or backend have changed since the last init.
if [[ $COMMAND != init ]]; then
  tofu init -input=false >/dev/null
fi
