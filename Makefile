.PHONY: dev prod status help

BUNDLE_NAME := consult

help:
	@echo "Consult Development Utilities"
	@echo ""
	@echo "Targets:"
	@echo "  make dev     - Convert to relative refs for local development"
	@echo "  make prod    - Convert to absolute refs for production/commit"
	@echo "  make status  - Show current reference state"
	@echo "  make help    - Show this help"

dev:
	@echo "Converting to development mode (relative references)..."
	@find . -name "*.md" -type f -exec sed -i.bak 's|@~/\.claude/$(BUNDLE_NAME)/|@./$(BUNDLE_NAME)/|g' {} \;
	@find . -name "*.md.bak" -type f -delete
	@echo "✓ Converted to @./$(BUNDLE_NAME)/ (local development)"

prod:
	@echo "Converting to production mode (absolute references)..."
	@find . -name "*.md" -type f -exec sed -i.bak 's|@\./$(BUNDLE_NAME)/|@~/.claude/$(BUNDLE_NAME)/|g' {} \;
	@find . -name "*.md.bak" -type f -delete
	@echo "✓ Converted to @~/.claude/$(BUNDLE_NAME)/ (production)"

status:
	@echo "Reference Status:"
	@echo ""
	@echo "Relative references (@./$(BUNDLE_NAME)/):"
	@grep -r "@\./$(BUNDLE_NAME)/" . --include="*.md" 2>/dev/null | wc -l | xargs echo "  Count:"
	@echo ""
	@echo "Absolute references (@~/.claude/$(BUNDLE_NAME)/):"
	@grep -r "@~/\.claude/$(BUNDLE_NAME)/" . --include="*.md" 2>/dev/null | wc -l | xargs echo "  Count:"
	@echo ""
	@if grep -r "@\./$(BUNDLE_NAME)/" . --include="*.md" 2>/dev/null | grep -q .; then \
		echo "Status: DEVELOPMENT mode"; \
	else \
		echo "Status: PRODUCTION mode (ready to commit)"; \
	fi
