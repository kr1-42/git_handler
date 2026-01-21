#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_path="${script_dir}/git-handler.sh"
install_path="/usr/bin/git-handler"
user_install_path="$HOME/git_handler/git-handler.sh"
shell_rc="$HOME/.bashrc"

if [[ ! -f "${source_path}" ]]; then
  echo "Source script not found at ${source_path}" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  if [[ "${source_path}" != "${user_install_path}" ]]; then
    install -m 0755 "${source_path}" "${user_install_path}"
  fi

  if [[ ! -f "${shell_rc}" ]]; then
    touch "${shell_rc}"
  fi

  if grep -q '^alias git-handler=' "${shell_rc}"; then
    sed -i "s#^alias git-handler=.*#alias git-handler=\"bash ${user_install_path}\"#" "${shell_rc}"
  elif ! grep -Fq "alias git-handler=\"bash ${user_install_path}\"" "${shell_rc}"; then
    {
      echo ""
      echo "# git-handler alias"
      echo "alias git-handler=\"bash ${user_install_path}\""
    } >> "${shell_rc}"
  fi

  echo "Installed to ${user_install_path}"
  source "${shell_rc}"
  echo "Alias added to ${shell_rc} and loaded in this shell."
  exit 0
fi

install -m 0755 "${source_path}" "${install_path}"

echo "Installed to ${install_path}"
