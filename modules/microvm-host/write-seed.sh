# shellcheck shell=bash
install -d -m 0750 -g kvm "$SEED_DIRECTORY"
staging=$(mktemp -d -p /run)
trap 'rm -rf "$staging" "$SEED_IMAGE.tmp"' EXIT

for secret_name in "${!SECRET_FILES[@]}"; do
  secret_file=${SECRET_FILES[$secret_name]}
  seed_path=${SECRET_SEED_PATHS[$secret_name]}
  if ! install -D -m 0400 "$secret_file" "$staging/$seed_path"; then
    echo "$VM_NAME: secret $secret_name is not generated" >&2
    exit 1
  fi
done

truncate -s "${SEED_SIZE_MIB}M" "$SEED_IMAGE.tmp"
mkfs.ext4 -q -F -L "$SEED_LABEL" -d "$staging" "$SEED_IMAGE.tmp"
chown microvm:kvm "$SEED_IMAGE.tmp"
chmod 0400 "$SEED_IMAGE.tmp"
mv "$SEED_IMAGE.tmp" "$SEED_IMAGE"
