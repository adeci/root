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

# A stale lock file fails init when Nix bumps a provider and pins the old build on a rebuild.
rm -f .terraform.lock.hcl

# tofu won't run once the config's providers or backend have changed since the last init.
if [[ $COMMAND != init ]]; then
  tofu init -input=false >/dev/null
fi
