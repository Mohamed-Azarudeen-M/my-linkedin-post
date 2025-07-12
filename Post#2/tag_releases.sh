#!/bin/bash
set -e # Exit on any error

# Purpose: Tags and optionally pushes releases to remote Git repositories for multiple microservices using a JSON file
# with repository-tag mappings (e.g., {"repo-1":"v1.0.1","repo-2":"v2.0.0"}).
# Usage: ./tag_releases.sh [-p|--push] -f|--file <tag_file>
# Options:
#   -p, --push        Push tags to the remote repository
#   -f, --file        JSON file with repository-tag mappings

# Default base directory for repositories
BASE_DIR="${BASE_DIR:-$HOME/projects}"

# Initialize variables
PUSH="false"
TAG_FILE=""

# Parse command-line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--push)
        PUSH="true"
        shift
        ;;
      -f|--file)
        if [[ -z "$2" ]]; then
          echo "Error: --file requires a JSON file path"
          exit 1
        fi
        TAG_FILE="$2"
        shift 2
        ;;
      *)
        echo "Error: Unknown option '$1'"
        echo "Usage: $0 [-p|--push] -f|--file <tag_file>"
        exit 1
        ;;
    esac
  done
}

# Validate JSON file existence and jq dependency
validate_input() {
  if [[ -z "$TAG_FILE" ]]; then
    echo "Error: JSON file required. Usage: $0 [-p|--push] -f|--file <tag_file>"
    exit 1
  fi
  if [[ ! -f "$TAG_FILE" ]]; then
    echo "Error: Tag file '$TAG_FILE' does not exist"
    exit 1
  fi
  if ! command -v jq >/dev/null; then
    echo "Error: 'jq' is required to parse JSON tag file"
    exit 1
  fi
}

# Check if a repository is a valid Git repo and clean
is_repo_valid_and_clean() {
  local repo_directory="$1"
  if ! git -C "$repo_directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: '$repo_directory' is not a valid Git repository"
    return 1
  fi
  if [ -n "$(git -C "$repo_directory" status --porcelain)" ]; then
    echo "Error: '$repo_directory' is dirty, please clean and try again"
    return 1
  fi
  return 0
}

# Check out main or master branch and pull latest changes
prepare_repo_branch() {
  local repo_directory="$1"
  local branches=$(git -C "$repo_directory" for-each-ref --format='%(refname:short)' refs/heads/)
  if echo "$branches" | grep -q 'main'; then
    echo "Checking out main branch for '$repo_directory'"
    git -C "$repo_directory" checkout main
    git -C "$repo_directory" fetch
    git -C "$repo_directory" pull
  elif echo "$branches" | grep -q 'master'; then
    echo "Checking out master branch for '$repo_directory'"
    git -C "$repo_directory" checkout master
    git -C "$repo_directory" fetch
    git -C "$repo_directory" pull
  else
    echo "Error: No main or master branch found in '$repo_directory'"
    return 1
  fi
  return 0
}

# Tag the repository and optionally push the tag
apply_and_push_tag() {
  local repo_dir="$1"
  local release_tag="$2"
  local existing_remote_tags=$(git -C "$repo_dir" ls-remote --tags origin | awk '{print $2}' | sed 's|refs/tags/||')

  if echo "$existing_remote_tags" | grep -q "^${release_tag}$"; then
    echo "Tag '$release_tag' already exists on remote for '$repo_dir', skipping"
    return 0
  fi

  echo "Tagging '$release_tag' for '$repo_dir'"
  if ! git -C "$repo_dir" tag "$release_tag"; then
    echo "Error: Failed to create tag '$release_tag' in '$repo_dir'"
    return 1
  fi

  if [[ "$PUSH" == "true" ]]; then
    echo "Pushing tag '$release_tag' for '$repo_dir'"
    if ! git -C "$repo_dir" push origin "$release_tag"; then
      echo "Error: Failed to push tag '$release_tag' to remote for '$repo_dir'"
      return 1
    fi
  fi
  return 0
}

# Main script execution
main() {
  # Parse arguments
  parse_args "$@"

  # Validate input
  validate_input

  # Inform user about push mode
  if [[ "$PUSH" == "true" ]]; then
    echo "Push mode enabled, will push tags to remote repositories."
  else
    echo "Running in setup mode, will not push tags."
  fi

  # Process JSON file
  while IFS="=" read -r repo tag; do
    if [[ -z "$repo" || -z "$tag" ]]; then
      echo "Warning: Invalid repo:tag pair in '$TAG_FILE', skipping"
      continue
    fi
    full_dir="${BASE_DIR}/${repo}"
    echo "Processing repository: '$full_dir' with tag '$tag'"

    # Validate repository
    if ! is_repo_valid_and_clean "$full_dir"; then
      echo "Skipping '$full_dir' due to invalid or dirty state"
      continue
    fi

    # Prepare repository branch
    if ! prepare_repo_branch "$full_dir"; then
      echo "Skipping '$full_dir' due to missing main or master branch"
      continue
    fi

    # Apply and push tag
    if ! apply_and_push_tag "$full_dir" "$tag"; then
      echo "Skipping '$full_dir' due to tagging or pushing error"
      continue
    fi
  done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$TAG_FILE")
}

# Execute main function
main "$@"

exit 0
