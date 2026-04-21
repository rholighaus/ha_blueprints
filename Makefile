HA_PATH  := /config/blueprints/automation/rholighaus
HA_URL   := http://homeassistant:8123
HA_TOKEN ?= $(shell cat ~/.ha_token 2>/dev/null | tr -d '[:space:]')

# ── Push to GitHub ────────────────────────────────────────────────────────────
push:
	git add .
	git commit -m "Update blueprints" || true
	git push

# ── Pull all blueprints from HA to Mac ───────────────────────────────────────
pull-from-ha:
	@ssh homeassistant "ls '$(HA_PATH)'/*.yaml" | while IFS= read -r f; do \
		name=$$(basename "$$f"); \
		ssh homeassistant "cat \"$$f\"" > "blueprints/automation/$$name" && \
		echo "← HA: $$name"; \
	done

# ── Copy all blueprints from Mac to HA via REST API ──────────────────────────
sync-to-ha:
	@if [ -z "$(HA_TOKEN)" ]; then \
		echo "Error: ~/.ha_token not found or empty"; exit 1; \
	fi
	@find blueprints/automation -name "*.yaml" | while IFS= read -r f; do \
		name=$$(basename "$$f"); \
		content=$$(base64 < "$$f" | tr -d '\n'); \
		curl -sf -X POST "$(HA_URL)/api/services/shell_command/goodwe_set_power_phase_a" \
			-H "Authorization: Bearer $(HA_TOKEN)" \
			-H "Content-Type: application/json" \
			-d "{\"value\": \"0; python3 -c \\\"import base64; open('$(HA_PATH)/$$name','wb').write(base64.b64decode('$$content'))\\\"\"}" \
			> /dev/null && echo "→ HA: $$name"; \
	done

# ── Reload blueprints on HA ───────────────────────────────────────────────────
reload-ha:
	@if [ -z "$(HA_TOKEN)" ]; then \
		echo "Error: ~/.ha_token not found or empty"; exit 1; \
	fi
	@curl -sf -X POST "$(HA_URL)/api/services/homeassistant/reload_all" \
		-H "Authorization: Bearer $(HA_TOKEN)" \
		-H "Content-Type: application/json" && echo "HA reloaded"

# ── Push to GitHub and sync to HA ────────────────────────────────────────────
deploy: push sync-to-ha

# ── Bump version in ALL blueprints ───────────────────────────────────────────
# Usage: make bump-version VERSION=1.1
bump-version:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make bump-version VERSION=1.1"; exit 1; fi
	@find blueprints/automation -name "*.yaml" | while IFS= read -r f; do \
		sed -i '' "s/\*\*Version: [0-9][0-9.]*\*\*/**Version: $(VERSION)**/" "$$f" && \
		echo "Bumped: $$(basename $$f) -> $(VERSION)"; \
	done

# ── Bump version in a SINGLE blueprint ───────────────────────────────────────
# Usage: make bump-file FILE="charge-powerwall-when-throttling.yaml" VERSION=1.2
bump-file:
	@if [ -z "$(FILE)" ] || [ -z "$(VERSION)" ]; then \
		echo 'Usage: make bump-file FILE="filename.yaml" VERSION=1.2'; exit 1; \
	fi
	@f="blueprints/automation/$(FILE)"; \
	if [ ! -f "$$f" ]; then echo "Error: $$f not found"; exit 1; fi; \
	sed -i '' "s/\*\*Version: [0-9][0-9.]*\*\*/**Version: $(VERSION)**/" "$$f" && \
	echo "Bumped: $(FILE) -> $(VERSION)"

# ── Release a single blueprint ────────────────────────────────────────────────
# Usage: make release-file FILE="charge-powerwall-when-throttling.yaml" VERSION=1.2
release-file:
	@if [ -z "$(FILE)" ] || [ -z "$(VERSION)" ]; then \
		echo 'Usage: make release-file FILE="filename.yaml" VERSION=1.2'; exit 1; \
	fi
	@$(MAKE) bump-file FILE="$(FILE)" VERSION=$(VERSION)
	@git add "blueprints/automation/$(FILE)"
	@git diff --cached --quiet && echo "Nothing to commit (version already at $(VERSION))" || \
		git commit -m "$(FILE): v$(VERSION)"
	@git push
	@stem=$$(basename "$(FILE)" .yaml); \
	tag="v$(VERSION)-$$stem"; \
	git tag "$$tag" && git push origin "$$tag" && echo "Tagged: $$tag"
	@$(MAKE) sync-to-ha
	@echo "Done. Create release notes at: https://github.com/rholighaus/ha_blueprints/releases"

# ── Release ALL blueprints ────────────────────────────────────────────────────
# Usage: make release VERSION=1.1
release:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make release VERSION=1.1"; exit 1; fi
	@$(MAKE) bump-version VERSION=$(VERSION)
	@$(MAKE) push
	@git tag "v$(VERSION)" && git push origin "v$(VERSION)"
	@$(MAKE) sync-to-ha
	@echo "Done. Create release notes at: https://github.com/rholighaus/ha_blueprints/releases"

.PHONY: push pull-from-ha sync-to-ha reload-ha deploy bump-version bump-file release-file release
