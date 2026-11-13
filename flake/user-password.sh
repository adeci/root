# shellcheck shell=bash
prompt_value=$(cat "${prompts:?}"/user-password)
if [[ -n "${prompt_value-}" ]]; then
  echo "$prompt_value" | tr -d "\n" > "${out:?}"/user-password
else
  xkcdpass --numwords 4 --delimiter - --count 1 | tr -d "\n" > "${out:?}"/user-password
fi
mkpasswd -s -m sha-512 < "$out"/user-password | tr -d "\n" > "$out"/user-password-hash
