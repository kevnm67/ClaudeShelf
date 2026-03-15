# ClaudeShelf — macOS SwiftUI App
# Usage: make help

PROJECT       := ClaudeShelf
SCHEME        := ClaudeShelf
DESTINATION   := platform=macOS
DERIVED_DATA  := $(HOME)/Library/Developer/Xcode/DerivedData
RESULT_BUNDLE := .build/results.xcresult

.DEFAULT_GOAL := help

.PHONY: help setup generate build test lint format clean ci coverage open

help: ## Show all available targets
	@echo "ClaudeShelf — available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

setup: ## Install dependencies (brew) and generate Xcode project
	brew install xcodegen xcbeautify xcresultparser 2>/dev/null || true
	xcodegen generate

generate: ## Generate Xcode project from project.yml
	xcodegen generate

build: generate ## Build the project (Debug, macOS)
	set -o pipefail && xcodebuild build \
		-project $(PROJECT).xcodeproj \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration Debug \
		CODE_SIGN_IDENTITY=- \
		| xcbeautify 2>/dev/null || cat

test: generate ## Run tests with code coverage enabled
	set -o pipefail && xcodebuild test \
		-project $(PROJECT).xcodeproj \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration Debug \
		-enableCodeCoverage YES \
		-resultBundlePath $(RESULT_BUNDLE) \
		CODE_SIGN_IDENTITY=- \
		| xcbeautify 2>/dev/null || cat

lint: ## Run SwiftLint (if installed)
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --strict; \
	else \
		echo "swiftlint not installed — skipping (brew install swiftlint)"; \
	fi

format: ## Run SwiftFormat (if installed)
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat .; \
	else \
		echo "swiftformat not installed — skipping (brew install swiftformat)"; \
	fi

clean: ## Clean build artifacts and DerivedData
	xcodebuild clean \
		-project $(PROJECT).xcodeproj \
		-scheme $(SCHEME) \
		2>/dev/null || true
	@echo "Removing DerivedData for $(PROJECT)..."
	@rm -rf $(DERIVED_DATA)/$(PROJECT)-*
	@rm -rf .build

ci: lint build test ## Run lint, build, and test (CI pipeline)

coverage: test ## Run tests and extract coverage report
	@if [ -d "$(RESULT_BUNDLE)" ]; then \
		xcrun xccov view --report $(RESULT_BUNDLE); \
	else \
		echo "No result bundle found at $(RESULT_BUNDLE). Run 'make test' first."; \
	fi

open: ## Open the Xcode project
	open $(PROJECT).xcodeproj
