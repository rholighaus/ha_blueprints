HA_PATH  := /config/blueprints/automation/rholighaus
HA_URL   := http://homeassistant.local:8123
HA_TOKEN ?= $(shell cat ~/.ha_token 2>/dev/null | tr -d '[:space:]')
HA_SSH   := root@homeassistant.local

# Automation IDs that use rholighaus blueprints — must be re-saved after any blueprint update
# because HA does not recompile blueprint instances unless their stored config changes.
BLUEPRINT_AUTOMATION_IDS := \
	automation.grange_a_solar_battery_reserve \
	automation.grange_b_solar_battery_reserve \
	automation.grange_c_solar_battery_reserve \
	automation.octopus_go_tesla_optimisation \
	automation.powerwall_backup_reserve_periodic_safety_reset
# Note: automation.grange_{a,b,c}_charge_powerwall_when_throttling removed
# 2026-07-20 — these entity IDs don't exist; the real automations for
# charge-powerwall-when-throttling.yaml are the *_solar_battery_reserve ones above.

# ── Push to GitHub ────────────────────────────────────────────────────────────
push:
	git add .
	git commit -m "Update blueprints" || true
	git push

# ── Pull all blueprints from HA to Mac ───────────────────────────────────────
pull-from-ha:
	@ssh $(HA_SSH) 'ls $(HA_PATH)/*.yaml' | while IFS= read -r f; do \
		name=$$(basename "$$f"); \
		scp -q $(HA_SSH):"$$f" "blueprints/automation/$$name" && \
		echo "← HA: $$name"; \
	done

# ── Copy all blueprints from Mac to HA via SCP ───────────────────────────────
# SCP is reliable with YAML special characters — no base64 or JSON escaping needed.
# After copying, reload HA and resave automation instances to recompile blueprints.
sync-to-ha:
	@find blueprints/automation -name "*.yaml" | while IFS= read -r f; do \
		name=$$(basename "$$f"); \
		scp -q "$$f" $(HA_SSH):$(HA_PATH)/"$$name" && \
		echo "→ HA: $$name"; \
	done
	@$(MAKE) reload-ha
	@$(MAKE) resave-automations

# ── Re-save all blueprint automation instances ────────────────────────────────
# HA does not recompile blueprint instances on restart unless their stored
# config changes. After any blueprint update, instances must be re-saved.
resave-automations:
	@if [ -z "$(HA_TOKEN)" ]; then \
		echo "Error: ~/.ha_token not found or empty"; exit 1; \
	fi
	@echo "Re-saving blueprint automation instances..."
	@for id in $(BLUEPRINT_AUTOMATION_IDS); do \
		config=$$(curl -s -X GET "$(HA_URL)/api/config/automation/config/$${id#automation.}" \
			-H "Authorization: Bearer $(HA_TOKEN)"); \
		resave_code=$$(curl -s -o /tmp/resave_out.txt -w "%{http_code}" \
			-X POST "$(HA_URL)/api/config/automation/config/$${id#automation.}" \
			-H "Authorization: Bearer $(HA_TOKEN)" \
			-H "Content-Type: application/json" \
			-d "$$config"); \
		echo "  ↺ $$id ($$resave_code)"; \
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

.PHONY: push pull-from-ha sync-to-ha resave-automations reload-ha deploy bump-version bump-file release-file release
