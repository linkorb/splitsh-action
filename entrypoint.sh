#!/bin/sh

set -eu

# ==========================================
# ANSI Colors & Logging Helpers (POSIX compliant for ash/BusyBox)
# ==========================================
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'

log_header() {
  printf "::endgroup::\n"
  printf "::group::${C_CYAN}${C_BOLD}=== %s ===${C_RESET}\n\n" "$1"
}
log_error()          { printf "${C_RED}${C_BOLD}ERROR:${C_RESET} ${C_RED}%s${C_RESET}\n" "$1" >&2; }
log_success()        { printf "${C_GREEN}✔ %s${C_RESET}\n" "$1"; }
log_info()           { printf "${C_BOLD}%s${C_RESET}\n" "$1"; }
log_value()          { printf "  %-12s ${C_YELLOW}%s${C_RESET}\n" "$1:" "$2"; }
# ==========================================

log_header "Starting repository split"
log_value "Version" "${SPLITSH_ACTION_VERSION:-unknown}"
log_value "Dry run" "${DRY_RUN:-false}"

# ==========================================

if [ "$#" -ne 4 ]; then
  log_error "Invalid number of arguments. Expected 4, got $#."
  exit 1
fi

prefix=$1
remote=$2
reference=$3
as_tag=$4

DRY_RUN=${DRY_RUN:-false}
DRY_RUN_FLAG=""

# Strictly check if DRY_RUN is exactly "true"
if [ "$DRY_RUN" = "true" ]; then
  DRY_RUN_FLAG="--dry-run"
fi

log_info "Arguments received:"
log_value "Prefix" "$prefix"
log_value "Remote" "$remote"
log_value "Reference" "$reference"
log_value "As tag" "$as_tag"

if [ -n "$DRY_RUN_FLAG" ]; then
  log_value "Dry-run" "Yes"
else
  log_value "Dry-run" "No"
fi

# ==========================================

log_header "Checking environment"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  log_error "GITHUB_TOKEN is not set."
  exit 1
fi

if [ -z "${GITHUB_WORKSPACE:-}" ]; then
  log_error "GITHUB_WORKSPACE is not set."
  exit 1
fi

log_success "GITHUB_TOKEN is set."
log_value "Workspace" "$GITHUB_WORKSPACE"

# ==========================================

log_header "GitHub-Cli Auth status"
gh auth status

# ==========================================

log_header "Configuring GitHub CLI authentication for Git"
gh auth setup-git
log_success "Configured"

# ==========================================

log_header "Preparing remote URL"

# POSIX string manipulation using case
case "$remote" in
  git@github.com:*)
    remote_https="https://github.com/${remote#git@github.com:}"
    ;;
  https://github.com/*)
    remote_https="$remote"
    ;;
  *)
    log_error "Unsupported remote URL: $remote"
    exit 1
    ;;
esac

log_success "Remote URL converted successfully."
log_value "HTTPS URL" "$remote_https"

# ==========================================

log_header "Configuring Git"

log_info "Adding GitHub workspace as a safe directory..."
git config --global --add safe.directory "$GITHUB_WORKSPACE"

log_info "Removing GitHub Actions checkout authentication header..."
git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true

log_success "Git configuration complete."

# ==========================================

log_header "Checking splitsh-lite"

if [ ! -x /usr/local/bin/splitsh-lite ]; then
  log_error "splitsh-lite not found or not executable at:"
  log_error "  /usr/local/bin/splitsh-lite"
  exit 1
fi

log_success "splitsh-lite found."
/usr/local/bin/splitsh-lite --version 2>/dev/null || true

# ==========================================

log_header "Configuring target remote"

if git remote get-url splitsh_target_remote >/dev/null 2>&1; then
  log_info "Existing splitsh_target_remote found. Removing it..."
  git remote remove splitsh_target_remote
fi

log_info "Adding target remote..."
git remote add splitsh_target_remote "$remote_https"

log_success "Target remote configured successfully."

# ==========================================

log_header "Testing target repository access"

log_info "Running git ls-remote against target repository..."
log_value "Remote" "$remote_https"

if git ls-remote splitsh_target_remote; then
  log_success "git ls-remote succeeded."
  log_info "Target repository is accessible with the provided GitHub authentication."
else
  log_error "git ls-remote failed."
  log_error "The target repository may not be accessible with the provided token."
  log_error "Please make sure that the actions/checkout step was run with persist-credentials: false"
  exit 1
fi

# ==========================================

log_header "Splitting repository"
log_value "Prefix" "$prefix"

SHA1=$(/usr/local/bin/splitsh-lite --prefix="$prefix")

if [ -z "$SHA1" ]; then
  log_error "splitsh-lite completed but returned an empty SHA."
  exit 1
fi

log_success "Repository split completed successfully."
log_value "Commit SHA" "$SHA1"

# ==========================================

log_header "Preparing push"

if [ "$as_tag" = "true" ]; then
  target_ref="refs/tags/$reference"
  target_type="tag"
else
  target_ref="refs/heads/$reference"
  target_type="branch"
fi

log_value "Target type" "$target_type"
log_value "Target ref" "$target_ref"
log_value "Commit SHA" "$SHA1"
log_value "Full refspec" "$SHA1:$target_ref"

# ==========================================

log_header "Pushing split repository"

log_info "Starting git push..."

git push splitsh_target_remote \
  "$SHA1:$target_ref" \
  --force \
  --verbose \
  $DRY_RUN_FLAG

# ==========================================


if [ -n "$DRY_RUN_FLAG" ]; then
  log_header "SUCCESS [dry-run]"
else
  log_header "SUCCESS"
fi

log_success "Repository split and pushed successfully."
log_value "Commit" "$SHA1"
log_value "Target" "$target_ref"

if [ -n "$DRY_RUN_FLAG" ]; then
  log_info "[DRY RUN: no changes were actually pushed]"
fi
