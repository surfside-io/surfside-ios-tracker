# Surfside iOS tracker — dev task shortcuts.
#
# Test layout (two SwiftPM test targets):
#   Tests             — unit tests, no external deps. This is the fast, always-green path.
#   IntegrationTests  — TestTrackEventsToMicro, requires a Snowplow Micro collector
#                       listening on http://localhost:9090 (see `test-integration`).
#
# Plain `swift test` runs BOTH, so without Micro running you get ~48 red from the
# integration target. Use `test-unit` for the everyday loop.

.DEFAULT_GOAL := help
.PHONY: help build test test-unit test-integration test-all micro

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: ## Build the package
	swift build

test: test-unit ## Alias for test-unit (the safe default)

test-unit: ## Run unit tests only (skips the Micro integration target)
	swift test --skip IntegrationTests

test-integration: ## Run integration tests only (needs Micro on :9090 — see `make micro`)
	swift test --filter IntegrationTests

test-all: ## Run everything (unit + integration; integration needs Micro on :9090)
	swift test

micro: ## Start a local Snowplow Micro collector on :9090 (foreground; Ctrl-C to stop)
	docker run --rm -p 9090:9090 snowplow/snowplow-micro:latest
