HA_PATH := /config/blueprints/automation/rholighaus

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
deploy: push sync-to-ha

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

# Reload blueprints on HA (via homeassistant.reload_all)
reload-ha:
	@ssh homeassistant "curl -sf -X POST \
		http://localhost:8123/api/services/homeassistant/reload_all \
		-H 'Authorization: Bearer $$(cat /run/secrets/hassio_token)' \
		-H 'Content-Type: application/json'" && echo "HA reloaded"

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
