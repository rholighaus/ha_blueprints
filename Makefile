HA_PATH := /config/blueprints/automation/rholighaus
HA_URL := http://10.27.3.10:8123
HA_TOKEN := $(shell cat ~/.ha_token 2>/dev/null)

# Push to GitHub
push:
	git add .
	git commit -m "Update blueprints" || true
	git push

# Copy all blueprints from Mac to HA
sync-to-ha:
	@find blueprints/automation -maxdepth 1 -name "*.yaml" -print0 | \
	while IFS= read -r -d '' f; do \
		ssh homeassistant "sudo tee \"$(HA_PATH)/$$(basename "$$f")\" > /dev/null" < "$$f" && \
		echo "→ HA: $$(basename "$$f")"; \
	done

# Pull all blueprints from HA to Mac
pull-from-ha:
	@ssh homeassistant "ls '$(HA_PATH)'/*.yaml" | while IFS= read -r f; do \
		ssh homeassistant "cat \"$$f\"" > "blueprints/automation/$$(basename "$$f")" && \
		echo "← HA: $$(basename "$$f")"; \
	done

# Push to GitHub and sync to HA
deploy: push sync-to-ha reload-ha

# Bump version in all blueprints (usage: make bump-version VERSION=1.1)
bump-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make bump-version VERSION=1.1"; exit 1; \
	fi
	@find blueprints/automation -maxdepth 1 -name "*.yaml" -print0 | \
	while IFS= read -r -d '' f; do \
		sed -i '' "s/\*\*Version: [0-9.]*\*\*/**Version: $(VERSION)**/" "$$f" && \
		echo "Bumped: $$(basename "$$f") -> $(VERSION)"; \
	done

# Reload automations on HA
reload-ha:
	@curl -sf -X POST "$(HA_URL)/api/services/automation/reload" \
		-H "Authorization: Bearer $(HA_TOKEN)" \
		-H "Content-Type: application/json" > /dev/null && echo "HA automations reloaded"

# Full workflow: bump version, deploy, tag release on GitHub
release:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make release VERSION=1.1"; exit 1; \
	fi
	$(MAKE) bump-version VERSION=$(VERSION)
	$(MAKE) deploy
	git tag v$(VERSION)
	git push origin v$(VERSION)
	@echo "Released v$(VERSION) — create release notes at https://github.com/rholighaus/ha_blueprints/releases"

.PHONY: push sync-to-ha pull-from-ha deploy bump-version reload-ha release
