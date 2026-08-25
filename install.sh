#!/bin/bash
set -euo pipefail

# ============================================================================
# Consult Installer
# Installs the Consult second-opinion plugin to ~/.claude/consult
# ============================================================================

# --- Constants ---
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# --- Configuration ---
readonly REPO_URL="https://github.com/daviguides/consult.git"
readonly TMP_DIR="/tmp/consult-$$"
readonly CLAUDE_DIR="$HOME/.claude"
readonly TARGET_DIR="$CLAUDE_DIR/consult"
readonly SOURCE_SUBDIR="consult"

# --- Marketplace Configuration ---
readonly MARKETPLACE_URL="https://github.com/daviguides/claude-marketplace.git"
readonly PLUGIN_IDENTIFIER="consult@daviguides"

# --- Cleanup ---
cleanup() {
  if [ -d "$TMP_DIR" ]; then
    printf "%b\n" "${BLUE}Cleaning up temporary files...${NC}"
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
  printf "%b\n" "${BLUE}Consult Installer${NC}"
  printf "%b\n\n" "${BLUE}===========================${NC}"
}

check_dependencies() {
  if ! command -v git >/dev/null 2>&1; then
    printf "%b\n" "${RED}Error: git is not installed${NC}"
    printf "%s\n" "Install: https://git-scm.com/downloads"
    exit 1
  fi
}

clone_repository() {
  printf "%b\n" "${BLUE}Cloning Consult repository...${NC}"

  if ! git clone --quiet "$REPO_URL" "$TMP_DIR" 2>/dev/null; then
    printf "%b\n" "${RED}Error: Failed to clone repository${NC}"
    printf "Repository: %s\n" "$REPO_URL"
    exit 1
  fi

  printf "%b\n\n" "${GREEN}✓ Repository cloned successfully${NC}"
}

validate_source_structure() {
  local src_subdir="$TMP_DIR/$SOURCE_SUBDIR"

  if [ ! -d "$src_subdir" ]; then
    printf "%b\n" "${RED}Error: expected subfolder not found:${NC} $src_subdir"
    printf "%s\n" "Repository structure may have changed. Verify 'consult/' exists at repo root."
    exit 1
  fi
}

copy_files() {
  local src_subdir="$TMP_DIR/$SOURCE_SUBDIR"

  mkdir -p "$TARGET_DIR"

  if command -v rsync >/dev/null 2>&1; then
    # Prefer rsync for better control
    rsync -a "$src_subdir"/ "$TARGET_DIR"/
  else
    # POSIX fallback (includes dotfiles)
    ( set -f; cp -R "$src_subdir"/. "$TARGET_DIR"/ )
  fi
}

install() {
  printf "%b\n" "${BLUE}Installing Consult to $TARGET_DIR...${NC}"

  # Ensure ~/.claude directory exists
  [ -d "$CLAUDE_DIR" ] || mkdir -p "$CLAUDE_DIR"

  # Remove existing installation
  [ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"

  copy_files

  printf "%b\n\n" "${GREEN}✓ Consult installed successfully!${NC}"
}

check_claude_cli() {
  if ! command -v claude >/dev/null 2>&1; then
    printf "%b\n" "${YELLOW}Warning: 'claude' CLI not found${NC}"
    printf "%s\n" "Skipping marketplace setup. Install Claude CLI to use marketplace features."
    return 1
  fi
  return 0
}

setup_marketplace() {
  printf "%b\n" "${BLUE}Setting up Claude Plugin Marketplace...${NC}"

  # Check if claude CLI is available
  if ! check_claude_cli; then
    return 0
  fi

  # Add marketplace if not already added
  printf "%b\n" "${BLUE}Adding marketplace...${NC}"
  if claude plugin marketplace add "$MARKETPLACE_URL" 2>/dev/null; then
    printf "%b\n" "${GREEN}✓ Marketplace added${NC}"
  else
    # Marketplace might already be added, that's fine
    printf "%b\n" "${BLUE}→ Marketplace already added or failed to add${NC}"
  fi

  # Install plugin from marketplace
  printf "%b\n" "${BLUE}Installing plugin from marketplace...${NC}"
  if claude plugin install "$PLUGIN_IDENTIFIER" 2>/dev/null; then
    printf "%b\n\n" "${GREEN}✓ Plugin installed from marketplace: $PLUGIN_IDENTIFIER${NC}"
  else
    printf "%b\n\n" "${YELLOW}⚠ Failed to install plugin from marketplace${NC}"
    printf "%s\n" "You can manually install with: claude plugin install $PLUGIN_IDENTIFIER"
  fi
}

print_next_steps() {
  printf "%b\n" "${GREEN}Installation complete!${NC}"
  printf "%b\n\n" "${BLUE}Next steps:${NC}"
  printf "%s\n" "1. Use /consult:ask to consult another model"
  printf "%s\n" "2. Targets: agy, kimi (auto), opus, fable, codex (explicit)"
  printf "%s\n" "3. Docs: https://github.com/daviguides/consult"
}

# ============================================================================
# Main
# ============================================================================

main() {
  print_header
  check_dependencies
  clone_repository
  validate_source_structure
  install
  setup_marketplace
  print_next_steps
}

# Entry point
main
