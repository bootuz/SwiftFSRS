.PHONY: help lint build test clean format

# Default target
help:
	@echo "Available targets:"
	@echo "  make lint      - Run SwiftLint with auto-fix"
	@echo "  make build     - Build the package"
	@echo "  make test      - Run tests"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make format    - Format and fix code style issues"

# Run SwiftLint with auto-fix
lint:
	swift package plugin --allow-writing-to-package-directory swiftlint --fix

# Format code (alias for lint)
format: lint

# Build the package
build:
	swift build

# Run tests
test:
	swift test

# Clean build artifacts
clean:
	swift package clean
