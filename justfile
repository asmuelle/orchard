# Orchard task runner — run `just` to list recipes.
# Requires: swift toolchain (Xcode 26+), swiftformat, swiftlint, xcbeautify, gh.
# See TOOLS.md for installation.

set shell := ["bash", "-uc"]

# Show available recipes
default:
    @just --list

# Install / verify the developer toolchain and resolve Swift packages
setup:
    @echo "🌳 Orchard — setup"
    @command -v swift >/dev/null || { echo "❌ Swift toolchain not found (need Xcode 26+)"; exit 1; }
    @command -v just  >/dev/null || echo "ℹ️  install just:        brew install just"
    @command -v swiftformat >/dev/null || echo "ℹ️  install swiftformat: brew install swiftformat"
    @command -v swiftlint   >/dev/null || echo "ℹ️  install swiftlint:   brew install swiftlint"
    @command -v xcbeautify  >/dev/null || echo "ℹ️  install xcbeautify:  brew install xcbeautify"
    @swift package resolve 2>/dev/null || echo "ℹ️  no Package.swift yet — skeleton stage"
    @echo "✅ setup checks complete"

# Build all targets (no-op until Package.swift exists — skeleton stage)
build:
    @if [ -f Package.swift ]; then swift build; else echo "ℹ️  no Package.swift yet — skeleton stage, nothing to build"; fi

# Run the test suite (no-op until Package.swift exists — skeleton stage)
test:
    @if [ -f Package.swift ]; then swift test; else echo "ℹ️  no Package.swift yet — skeleton stage, no tests"; fi

# Lint with swiftlint (no-op if not installed)
lint:
    @command -v swiftlint >/dev/null && swiftlint || echo "ℹ️  swiftlint not installed — skipping"

# Format sources with swiftformat (writes changes)
format:
    @command -v swiftformat >/dev/null && swiftformat . || echo "ℹ️  swiftformat not installed — skipping"

# Verify formatting without writing (used in CI)
format-check:
    @command -v swiftformat >/dev/null && swiftformat --lint . || echo "ℹ️  swiftformat not installed — skipping"

# Run the single-node demo (uses Foundation Models on OS 26+, else the stub engine)
demo: build
    .build/debug/orchard-demo

# The full check CI runs
ci: build test lint format-check
    @echo "✅ ci complete"

# Serve the GitHub Pages site locally at http://localhost:8000
site:
    @echo "🌐 serving docs/ at http://localhost:8000 (Ctrl-C to stop)"
    @cd docs && python3 -m http.server 8000

# Remove build artifacts
clean:
    swift package clean 2>/dev/null || true
    rm -rf .build

# Print a one-line project status
status:
    @echo "Orchard — concept skeleton. See DESIGN.md §9 for the roadmap."
