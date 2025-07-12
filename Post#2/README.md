# Automating Microservices Releases with `tag_releases.sh`

## Overview

`tag_releases.sh` is a Bash script designed to automate tagging and pushing releases for multiple Git repositories, specifically for microservices deployed on Google Cloud Run with tag-based triggers in Google Cloud Build. It uses a JSON file (e.g., `tags.json`) to map repositories to their respective tags, ensuring reliable and efficient releases.

## Problems Solved

1. **Manual Effort**: Eliminates the need to manually tag 12+ repositories, reducing 50+ commands to a single script execution.
2. **Error Prevention**: Validates repository cleanliness, branch availability, and tag uniqueness, preventing broken builds or deployments.
3. **Consistency**: Ensures all repositories are on `main` or `master` and up-to-date before tagging, maintaining release integrity.
4. **Scalability**: Handles any number of repositories via a JSON file, perfect for large microservices projects.
5. **CI/CD Integration**: Seamlessly integrates with Google Cloud Build by pushing tags to trigger production deployments.

## Time and Effort Savings

- **Manual Process**:
  - **Tasks**: Verify `tags.json`, navigate to 12 repositories, check cleanliness (`git status`), checkout `main`/`master` (`git checkout`), pull updates (`git pull`), create tags (`git tag`), push tags (`git push`).
  - **Commands**: \~50–60 commands for 12 services.
  - **Time**: 10–20 minutes per release, plus 5–10 minutes per error (e.g., dirty repository, duplicate tag).
  - **Total**: 10–60 minutes per release cycle.
- **Script Process**:
  - **Command**: `./tag_releases.sh -p -f tags.json`.
  - **Time**: \~10–30 seconds for 12 repositories, including validation, tagging, and pushing.
  - **Savings**: **\~90–95% time reduction**, saving 10–60 minutes per release, plus hours of error recovery.

## Prerequisites

- **Bash 3.2+**: Compatible with macOS (tested on macOS with Bash 3.2).
- **Git**: Installed and configured with access to repositories.
- **jq**: Required to parse the JSON file (`brew install jq` on macOS).
- **Repositories**: Must be under a base directory (default: `$HOME/projects`), with `main` or `master` branches.
- **JSON File**: A file (e.g., `tags.json`) with repository-tag mappings, e.g.:

  ```json
  {
    "repo-1": "v1.0.1",
    "repo-2": "v2.0.0",
    "repo-3": "v3.1.0"
  }
  ```
- **Google Cloud Build**: Configured with tag-based triggers (e.g., `v1.3.1`) for production deployments.

## Script Explanation

The script is organized into logical functions, executed in a `main` function for clarity:

1. **parse_args**: Parses command-line options (`-p|--push` for pushing tags, `-f|--file` for the JSON file).
2. **validate_input**: Checks if the JSON file exists and `jq` is installed.
3. **is_repo_valid_and_clean**: Verifies the repository is a valid Git repo with no uncommitted changes.
4. **prepare_repo_branch**: Checks out `main` or `master` and pulls the latest changes.
5. **apply_and_push_tag**: Creates a tag and pushes it (if `-p` is used), checking for existing tags to avoid duplicates.
6. **main**: Orchestrates the workflow, processing each repository-tag pair from the JSON file.

## How the Script Works

1. **Parse Arguments**: Reads `-p|--push` (to push tags) and `-f|--file <tag_file>` (e.g., `tags.json`).
2. **Validate Input**: Ensures the JSON file exists and `jq` is available.
3. **Process JSON File**:
   - Reads `tags.json` using `jq` to extract repository-tag pairs (e.g., `repo-1=v1.0.1`).
   - Skips invalid pairs (e.g., empty tags).
4. **For Each Repository**:
   - Validates the repository is clean and valid.
   - Checks out `main` or `master` and pulls updates.
   - Applies the tag (e.g., `v1.0.1`) and pushes it to trigger Google Cloud Build (if `-p` is used).
5. **Error Handling**: Skips problematic repositories (e.g., dirty, missing branch) with clear warnings, ensuring partial success.

## Example Usage

### JSON File (`tags.json`):

```json
{
  "repo-1": "v1.0.1",
  "repo-2": "v2.0.0",
  "repo-3": "v3.1.0"
}
```

### Command:

```bash
./tag_releases.sh -p -f tags.json
```

### Output (all repositories clean, on `main`):

```
Push mode enabled, will push tags to remote repositories.
Processing repository: /Users/helix/projects/repo-1 with tag 'v1.0.1'
Checking out main branch for '/Users/helix/projects/repo-1'
Tagging 'v1.0.1' for '/Users/helix/projects/repo-1'
Pushing tag 'v1.0.1' for '/Users/helix/projects/repo-1'
Processing repository: /Users/helix/projects/repo-2 with tag 'v2.0.0'
Checking out main branch for '/Users/helix/projects/repo-2'
Tagging 'v2.0.0' for '/Users/helix/projects/repo-2'
Pushing tag 'v2.0.0' for '/Users/helix/projects/repo-2'
Processing repository: /Users/helix/projects/repo-3 with tag 'v3.1.0'
Checking out main branch for '/Users/helix/projects/repo-3'
Tagging 'v3.1.0' for '/Users/helix/projects/repo-3'
Pushing tag 'v3.1.0' for '/Users/helix/projects/repo-3'
```

### Error Case (e.g., `repo-2` is dirty):

```
Push mode enabled, will push tags to remote repositories.
Processing repository: /Users/helix/projects/repo-1 with tag 'v1.0.1'
Checking out main branch for '/Users/helix/projects/repo-1'
Tagging 'v1.0.1' for '/Users/helix/projects/repo-1'
Pushing tag 'v1.0.1' for '/Users/helix/projects/repo-1'
Processing repository: /Users/helix/projects/repo-2 with tag 'v2.0.0'
Error: '/Users/helix/projects/repo-2' is dirty, please clean and try again
Skipping '/Users/helix/projects/repo-2' due to invalid or dirty state
Processing repository: /Users/helix/projects/repo-3 with tag 'v3.1.0'
Checking out main branch for '/Users/helix/projects/repo-3'
Tagging 'v3.1.0' for '/Users/helix/projects/repo-3'
Pushing tag 'v3.1.0' for '/Users/helix/projects/repo-3'
```

## Recommendations for Use

1. **Validate JSON Syntax**:
   - Add to `validate_input`:

     ```bash
     if ! jq . "$TAG_FILE" >/dev/null 2>&1; then
       echo "Error: Invalid JSON syntax in '$TAG_FILE'"
       exit 1
     fi
     ```
2. **Enforce Semantic Versioning**:
   - Add to the loop:

     ```bash
     if ! echo "$tag" | grep -qE '^[vV][0-9]+\.[0-9]+\.[0-9]+$'; then
       echo "Warning: Tag '$tag' for '$repo' does not match semantic versioning, skipping"
       continue
     fi
     ```
3. **Log Output**:
   - Save output for auditing:

     ```bash
     ./tag_releases.sh -p -f tags.json | tee release-20250712-2016.log
     ```
4. **Custom Branches**:
   - Add a `-b|--branch` option to support branches other than `main`/`master`.

## Full Script

```bash
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
```
