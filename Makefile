# Common developer tasks. Run `make help` for a list.

PROJECT      := ReportingBuilder.xcodeproj
SCHEME       := ReportingBuilder
DESTINATION  := platform=macOS
DERIVED_DATA := DerivedData
CORE_DIR     := Packages/ReportCore
XCODEBUILD   := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA)

.PHONY: help generate build run test test-core test-app test-ui lint format format-check archive clean open cli site lint-cards

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

generate: ## Regenerate the Xcode project from project.yml (needs xcodegen)
	xcodegen generate

build: ## Debug build of the app
	$(XCODEBUILD) -configuration Debug build | xcbeautify 2>/dev/null || $(XCODEBUILD) -configuration Debug build

run: build ## Build and launch the app
	open "$(DERIVED_DATA)/Build/Products/Debug/ReportingBuilder.app"

test: test-core test-app ## Run core package tests and app unit tests

test-core: ## Run the ReportCore package tests (fast, no Xcode project needed)
	cd $(CORE_DIR) && swift test

test-app: ## Run app unit tests (export, pasteboard, ingestion, store)
	$(XCODEBUILD) -configuration Debug test -only-testing:ReportingBuilderTests

test-ui: ## Run UI tests, including the XCTest accessibility audit (launches the app)
	$(XCODEBUILD) -configuration Debug test -only-testing:ReportingBuilderUITests

cli: ## Build the reportcard command-line tool and print its usage
	cd $(CORE_DIR) && swift run reportcard help

site: ## Generate the static card gallery into ./_site (what CI publishes to GitHub Pages)
	cd $(CORE_DIR) && swift run reportcard site --out "$(CURDIR)/_site"
	@echo "Open _site/index.html"

lint-cards: ## Accessibility-lint every built-in template, as the Pages workflow does
	cd $(CORE_DIR) && for t in $$(swift run reportcard templates | cut -f1); do swift run reportcard lint --template $$t --strict || exit 1; done

lint: ## Run SwiftLint (brew install swiftlint)
	swiftlint lint --strict

format: ## Apply SwiftFormat (brew install swiftformat)
	swiftformat .

format-check: ## Fail if SwiftFormat would change anything
	swiftformat --lint .

archive: ## Release archive (unsigned unless DEVELOPMENT_TEAM is set)
	$(XCODEBUILD) -configuration Release archive -archivePath build/ReportingBuilder.xcarchive

clean: ## Remove build products
	rm -rf $(DERIVED_DATA) build _site $(CORE_DIR)/.build

open: ## Open the project in Xcode
	open $(PROJECT)
