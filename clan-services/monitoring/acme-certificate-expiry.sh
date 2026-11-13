# shellcheck shell=bash
certificate_list=$1
output_file=$2

temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  echo '# HELP acme_certificate_expiry_timestamp_seconds When the ACME certificate expires.'
  echo '# TYPE acme_certificate_expiry_timestamp_seconds gauge'
  while IFS=$'\t' read -r name path; do
    if not_after=$(openssl x509 -enddate -noout -in "$path"); then
      echo "acme_certificate_expiry_timestamp_seconds{certificate=\"$name\"} $(date -d "${not_after#notAfter=}" +%s)"
    fi
  done < "$certificate_list"
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
trap - EXIT
