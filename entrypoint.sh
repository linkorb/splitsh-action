#!/usr/bin/env sh

set -eu

echo "=== Starting repository split ==="

if [ "$#" -ne 4 ]; then
  echo "ERROR: Invalid number of arguments. Expected 4, got $#." >&2
  exit 1
fi

prefix=$1
remote=$2
reference=$3
as_tag=$4

echo "Arguments received:"
echo "  Prefix:    $prefix"
echo "  Remote:    $remote"
echo "  Reference: $reference"
echo "  As tag:    $as_tag"

echo ""
echo "=== Checking environment ==="

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN is not set." >&2
  exit 1
fi

if [ -z "${GITHUB_WORKSPACE:-}" ]; then
  echo "ERROR: GITHUB_WORKSPACE is not set." >&2
  exit 1
fi

echo "GITHUB_TOKEN is set."
echo "GITHUB_WORKSPACE: $GITHUB_WORKSPACE"

echo ""
echo "=== Preparing remote URL ==="

case "$remote" in
  git@github.com:*)
    remote_https="https://github.com/${remote#git@github.com:}"
    ;;
  https://github.com/*)
    remote_https="$remote"
    ;;
  *)
    echo "ERROR: Unsupported remote URL: $remote" >&2
    exit 1
    ;;
esac

echo "Remote URL converted successfully:"
echo "  $remote_https"

authenticated_remote="https://${GITHUB_TOKEN}@${remote_https#https://}"

echo ""
echo "=== Configuring Git ==="

echo "Adding GitHub workspace as a safe directory..."
git config --global --add safe.directory "$GITHUB_WORKSPACE"

echo "Removing GitHub Actions checkout authentication header..."
git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true

echo "Git configuration complete."

echo ""
echo "=== Checking splitsh-lite ==="

if [ ! -x /usr/local/bin/splitsh-lite ]; then
  echo "ERROR: splitsh-lite not found or not executable at:" >&2
  echo "  /usr/local/bin/splitsh-lite" >&2
  exit 1
fi

echo "splitsh-lite found."
/usr/local/bin/splitsh-lite --version 2>/dev/null || true

echo ""
echo "=== Configuring target remote ==="

if git remote get-url splitsh_target_remote >/dev/null 2>&1; then
  echo "Existing splitsh_target_remote found. Removing it..."
  git remote remove splitsh_target_remote
else
  echo "No existing splitsh_target_remote found."
fi

echo "Adding target remote..."
git remote add splitsh_target_remote "$authenticated_remote"

echo "Target remote configured successfully."

echo ""
echo "=== Testing target repository access ==="

echo "Running git ls-remote against target repository..."
echo "Remote: $remote_https"

if git ls-remote splitsh_target_remote; then
  echo "git ls-remote succeeded."
  echo "Target repository is accessible with the provided token."
else
  echo "ERROR: git ls-remote failed." >&2
  echo "The target repository may not be accessible with the provided token." >&2
  exit 1
fi

echo ""
echo "=== Splitting repository ==="
echo "Prefix: $prefix"

SHA1=$(/usr/local/bin/splitsh-lite --prefix="$prefix")

if [ -z "$SHA1" ]; then
  echo "ERROR: splitsh-lite completed but returned an empty SHA." >&2
  exit 1
fi

echo "Repository split completed successfully."
echo "Generated commit SHA: $SHA1"

echo ""
echo "=== Preparing push ==="

if [ "$as_tag" = "true" ]; then
  target_ref="refs/tags/$reference"
  echo "Target type: tag"
else
  target_ref="refs/heads/$reference"
  echo "Target type: branch"
fi

echo "Target reference: $target_ref"
echo "Commit SHA:       $SHA1"
echo "Full refspec:     $SHA1:$target_ref"

echo ""
echo "=== Pushing split repository ==="

echo "Starting git push..."

git push splitsh_target_remote \
  "$SHA1:$target_ref" \
  --force \
  --verbose

echo ""
echo "=== SUCCESS ==="
echo "Repository split and pushed successfully."
echo "Commit: $SHA1"
echo "Target: $target_ref"
