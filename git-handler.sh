#!/usr/bin/env bash

if [[ -z "${BASH_VERSION-}" ]]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "git non è installato o non è presente nel PATH." >&2
  exit 1
fi

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BOLD=''
  RESET=''
fi

show_help() {
  cat << 'EOF'
git-handler - Semplifica i flussi Git con gestione dei branch feature

UTILIZZO:
  git-handler [OPTIONS]

OPZIONI:
  (nessuna opzione)   Flusso interattivo per branch feature
                      - Su main/master/trunk: crea o passa a un branch feature
                      - Su branch feature/*: fa commit di tutte le modifiche e push su origin

  --init <repo_url>   Inizializza il repository e fa push sul remoto
                      - Esegue git init se necessario
                      - Imposta origin a <repo_url>
                      - Crea il commit iniziale se non esistono commit
                      - Esegue il push su origin

  --push-dir <dir> <repo_url> [branch]
                      Esegue il push di una sottocartella verso un altro remoto
                      - Usa git subtree split per fare push di <dir>
                      - Il branch predefinito sul remoto di destinazione è 'main'

  --move-to-branch    Sposta modifiche non committate e/o commit locali in un nuovo branch
                      - Chiede il nome del nuovo branch
                      - Opzionalmente resetta il branch originale al suo upstream

  -h, --help          Mostra questo messaggio di aiuto

ESEMPI:
  git-handler
      Avvia o continua il flusso del branch feature

  git-handler --init git@github.com:user/repo.git
      Inizializza la directory corrente come repo e fa push su GitHub

    git-handler --push-dir frontend git@github.com:user/frontend.git main
      Esegue push solo della cartella 'frontend' sul branch main di un repo separato

  git-handler --move-to-branch
      Sposta lavoro fatto per errore su main in un nuovo branch

NOME DEI BRANCH:
  I nuovi branch hanno prefisso 'feature/'. Quando richiesto, inserisci solo il suffisso:
    Inserisci il nome del branch (senza 'feature/'): login-page
    Crea: feature/login-page

BRANCH PROTETTI:
  main, master, trunk - lo script non esegue commit direttamente su questi branch
EOF
}

if [[ "${1-}" == "-h" ]] || [[ "${1-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "${1-}" == "--init" ]]; then
  repo_url="${2-}"
  if [[ -z "${repo_url}" ]]; then
    echo "Utilizzo: $0 --init <repo_url>" >&2
    exit 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git init
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "${repo_url}"
  else
    git remote add origin "${repo_url}"
  fi

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    read -r -p "Messaggio commit iniziale [Commit iniziale]: " init_message
    init_message="${init_message:-Commit iniziale}"
    git add -A
    git commit -m "${init_message}"
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  git push -u origin "${current_branch}"
  echo "Repository inizializzato e push eseguito su ${repo_url} nel branch ${current_branch}."
  exit 0
fi

if [[ "${1-}" == "--push-dir" ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Non ti trovi dentro un repository git." >&2
    exit 1
  fi

  subdir_raw="${2-}"
  remote_url="${3-}"
  target_branch="${4:-main}"

  if [[ -z "${subdir_raw}" || -z "${remote_url}" ]]; then
    echo "Utilizzo: $0 --push-dir <dir> <repo_url> [branch]" >&2
    exit 1
  fi

  subdir="${subdir_raw#/}"
  subdir="${subdir%/}"

  if [[ -z "${subdir}" ]]; then
    echo "Il percorso della directory non può essere vuoto." >&2
    exit 1
  fi

  repo_root="$(git rev-parse --show-toplevel)"
  subdir_path="${repo_root}/${subdir}"

  if [[ ! -d "${subdir_path}" ]]; then
    echo "La directory '${subdir}' non esiste nel repository." >&2
    exit 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "La working tree contiene modifiche non committate. Fai commit o stash prima del push della directory." >&2
    exit 1
  fi

  remote_name="git-handler-${subdir//\//-}"

  if git remote get-url "${remote_name}" >/dev/null 2>&1; then
    git remote set-url "${remote_name}" "${remote_url}"
  else
    git remote add "${remote_name}" "${remote_url}"
  fi

  temp_branch="git-handler/subtree-${subdir//\//-}"

  if git show-ref --verify --quiet "refs/heads/${temp_branch}"; then
    git branch -D "${temp_branch}"
  fi

  git subtree split --prefix="${subdir}" -b "${temp_branch}"
  git push --force "${remote_name}" "${temp_branch}:${target_branch}"
  git branch -D "${temp_branch}"

  echo "Push di '${subdir}' eseguito verso ${remote_url} sul branch ${target_branch} usando il remoto '${remote_name}'."
  exit 0
fi

if [[ "${1-}" == "--move-to-branch" ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Non ti trovi dentro un repository git." >&2
    exit 1
  fi

  original_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${original_branch}" == "HEAD" ]]; then
    echo "HEAD scollegato (detached). Esegui prima il checkout di un branch." >&2
    exit 1
  fi

  status_output="$(git status --porcelain)"
  has_uncommitted=false
  if [[ -n "${status_output}" ]]; then
    has_uncommitted=true
  fi

  upstream_ref=""
  ahead_count=0
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name @{u})"
    ahead_count="$(git rev-list --count "${upstream_ref}..HEAD")"
  fi

  if [[ "${has_uncommitted}" == false ]] && (( ahead_count == 0 )); then
    echo "Nessuna modifica locale da spostare da '${original_branch}'."
    exit 0
  fi

  read -r -p "Inserisci il nome del nuovo branch: " new_branch
  new_branch="${new_branch## }"
  new_branch="${new_branch%% }"

  if [[ -z "${new_branch}" ]]; then
    echo "Il nome del branch non può essere vuoto." >&2
    exit 1
  fi

  if git show-ref --verify --quiet "refs/heads/${new_branch}"; then
    read -r -p "Il branch '${new_branch}' esiste già. Vuoi passarci? [s/N]: " switch_existing
    if [[ ! "${switch_existing}" =~ ^[SsYy]$ ]]; then
      echo "Operazione annullata." >&2
      exit 1
    fi
    git switch "${new_branch}"
  else
    git switch -c "${new_branch}"
  fi

  if (( ahead_count > 0 )) && [[ -n "${upstream_ref}" ]]; then
    read -r -p "Resettare '${original_branch}' a '${upstream_ref}' (rimuove ${ahead_count} commit da ${original_branch})? [s/N]: " reset_choice
    if [[ "${reset_choice}" =~ ^[SsYy]$ ]]; then
      git switch "${original_branch}"
      git reset --hard "${upstream_ref}"
      git switch "${new_branch}"
      echo "Commit spostati su '${new_branch}' e '${original_branch}' resettato a '${upstream_ref}'."
      exit 0
    fi
  fi

  echo "Lavoro spostato su '${new_branch}'."
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Non ti trovi dentro un repository git." >&2
  exit 1
fi

initial_branch="$(git rev-parse --abbrev-ref HEAD)"
current_branch="${initial_branch}"
use_existing_branch=false
on_feature_branch=false
is_protected_branch=false

if [[ "${initial_branch}" == feature/* ]]; then
  on_feature_branch=true
fi

case "${initial_branch}" in
  main|master|trunk)
    is_protected_branch=true
    ;;
esac

mapfile -t existing_branches < <(
  git for-each-ref --format='%(refname:short)' refs/heads
)

if [[ "${on_feature_branch}" == false ]] && [[ "${is_protected_branch}" == true ]]; then
  echo
  printf "${BOLD}Selezione branch${RESET}\n"
  echo "Branch corrente: ${current_branch}"
  echo "Scegli un branch esistente oppure creane uno nuovo di tipo feature."
  printf "${RED}${BOLD}  0) Crea un nuovo branch feature${RESET}\n"

  for i in "${!existing_branches[@]}"; do
    branch_label="${existing_branches[$i]}"
    if [[ "${branch_label}" == "${current_branch}" ]]; then
      branch_label+=" (corrente)"
    fi
    printf "  %d) %s\n" "$((i + 1))" "${branch_label}"
  done

  read -r -p "Inserisci numero o nome branch [0]: " selection
  selection="${selection## }"
  selection="${selection%% }"
  selection="${selection:-0}"

  target_branch=""
  if [[ "${selection}" =~ ^[0-9]+$ ]]; then
    if (( selection == 0 )); then
      target_branch=""
    elif (( selection >= 1 && selection <= ${#existing_branches[@]} )); then
      target_branch="${existing_branches[$((selection - 1))]}"
    else
      echo "Selezione non valida '${selection}'." >&2
      exit 1
    fi
  else
    target_branch="${selection}"
  fi

  if [[ -n "${target_branch}" ]]; then
    if git show-ref --verify --quiet "refs/heads/${target_branch}"; then
      if [[ "${target_branch}" != "${current_branch}" ]]; then
        git checkout "${target_branch}"
      fi
      current_branch="${target_branch}"
      use_existing_branch=true
    else
      echo "Il branch '${target_branch}' non esiste in locale." >&2
      exit 1
    fi
  fi
fi

skip_commit=false
if [[ "${is_protected_branch}" == true ]]; then
  skip_commit=true
fi

branch_name="${current_branch}"
if [[ "${on_feature_branch}" == false ]] && [[ "${use_existing_branch}" == false ]] && [[ "${is_protected_branch}" == true ]]; then
  read -r -p "Inserisci nome branch (senza 'feature/'): " branch_suffix
  branch_suffix="${branch_suffix## }"
  branch_suffix="${branch_suffix%% }"

  if [[ -z "$branch_suffix" ]]; then
    echo "Il nome del branch non può essere vuoto." >&2
    exit 1
  fi

  branch_name="feature/${branch_suffix}"

  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    echo "Il branch '${branch_name}' esiste già in locale. Eseguo checkout..."
    git checkout "${branch_name}"
  else
    git checkout -b "${branch_name}"
  fi
fi

if [[ "${skip_commit}" == true ]]; then
  echo "Partito da '${initial_branch}'. Passato a '${branch_name}'. Nessun commit o push eseguito."
  exit 0
fi

read -r -p "Messaggio di commit: " commit_message
commit_message="${commit_message## }"
commit_message="${commit_message%% }"

if [[ -z "$commit_message" ]]; then
  echo "Il messaggio di commit non può essere vuoto." >&2
  exit 1
fi

git add -A

git commit -m "${commit_message}"

git push -u origin "${branch_name}"

echo
printf "${GREEN}${BOLD}✓ Push completato${RESET}\n"
echo "Branch pubblicato: ${branch_name}"
echo "Remoto: origin"

target_branch="master"
if ! git show-ref --verify --quiet "refs/heads/${target_branch}"; then
  if git show-ref --verify --quiet "refs/heads/main"; then
    target_branch="main"
  elif git show-ref --verify --quiet "refs/heads/trunk"; then
    target_branch="trunk"
  else
    printf "${YELLOW}${BOLD}! Nessun branch principale trovato${RESET}\n"
    echo "Non è stato trovato master/main/trunk in locale. Checkout e pull saltati."
    exit 0
  fi
fi

echo
printf "${BOLD}Sincronizzazione branch principale${RESET}\n"
echo "Branch principale rilevato: ${target_branch}"
printf "${CYAN}Se il merge è già stato fatto, aggiorniamo ${target_branch} con git pull --ff-only.${RESET}\n"

git checkout "${target_branch}"

read -r -p "'${branch_name}' è già stato mergiato in '${target_branch}'? [s/N]: " merged_choice
if [[ "${merged_choice}" =~ ^[SsYy]$ ]]; then
  git pull --ff-only
  printf "${GREEN}${BOLD}✓ ${target_branch} aggiornato correttamente.${RESET}\n"
else
  printf "${YELLOW}Pull di ${target_branch} saltato. Eseguilo dopo il merge del branch.${RESET}\n"
fi

exit 0
