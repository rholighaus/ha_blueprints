# ha_blueprints — Claude Code Context

## What this repo is
Home Assistant automation blueprints for the property at The Grange Bourton.
Blueprints are stored on Home Assistant and mirrored here on GitHub.

## Repository structure
```
blueprints/automation/
├── charge-powerwall-when-throttling.yaml
├── Goodwe g100 throttle.yaml
├── powerwall-octopus-go-cheap-charging.yaml
├── Vesternet 8 Button Zigbee Wall Controller z2m.yaml
└── warp-solar-excess-charging.yaml
Makefile
CLAUDE.md
```

## Home Assistant access
- SSH alias: `homeassistant`
- Blueprint path on HA: `/config/blueprints/automation/rholighaus/`
- HA version: 2026.4.2
- HA MCP is connected — use it for automation/entity management

## Key entities
### GoodWe throttling dispatch switches (input_boolean)
- Phase A: `input_boolean.goodwe_phase_a_throttling_active`
- Phase B: `input_boolean.goodwe_phase_b_throttling_active`
- Phase C: `input_boolean.goodwe_phase_c_throttling_active`

### Tesla Powerwall backup reserves (Teslemetry)
- Grange A: `number.the_grange_a_backup_reserve`
- Grange B: `number.the_grange_b_backup_reserve`
- Grange C: `number.the_grange_c_backup_reserve`

### Battery SoC sensors
- Grange A: `sensor.the_grange_a_percentage_charged`
- Grange B: `sensor.the_grange_b_percentage_charged`
- Grange C: `sensor.the_grange_c_percentage_charged`

### Octopus Energy
- Current rate: `sensor.octopus_energy_electricity_25j0223825_2000012019734_current_rate`
- Cheap (Go) rate is ~0.052 GBP/kWh, active 23:30–05:30

### Notifications
- Ralf's iPhone: `notify.mobile_app_ralfs_iphone`

## Active automations created in this project
- `automation.grange_a_charge_powerwall_when_throttling` — blueprint instance
- `automation.grange_b_charge_powerwall_when_throttling` — blueprint instance
- `automation.grange_c_charge_powerwall_when_throttling` — blueprint instance
- `automation.powerwall_backup_reserve_periodic_safety_reset` — standalone, runs every 30 min + HA start

## Blueprint conventions
- All blueprints must have `source_url` pointing to this GitHub repo (required by blueprints_updater custom component)
- URL format: `https://github.com/rholighaus/ha_blueprints/blob/main/blueprints/automation/<filename>`
- Spaces in filenames must be encoded as `%20` in the URL
- Version is tracked in the `description` field as `**Version: X.Y**`
- Default version is `1.0`

## Important quirks discovered
- `blueprints_updater` custom component silently ignores blueprints without a valid `source_url` — they won't appear in the Blueprints UI
- HA 2026.4 rejects `source_url: null` — omit the field or use a real URL
- `battery_soc_sensor` input default must be bare `default:` not `default: null`
- Blueprint files must be saved with Unix line endings (LF not CRLF)

## Makefile targets
```bash
make deploy              # commit + push to GitHub + sync to HA
make pull-from-ha        # pull latest files from HA to Mac
make sync-to-ha          # push Mac files to HA
make bump-version VERSION=1.1   # bump version in all blueprints
make release VERSION=1.1        # bump + deploy + git tag
```

## Workflow
- Edit blueprints on Mac → `make deploy`
- Edit blueprints on HA via File Editor → `make pull-from-ha` then `make push`
- New release → `make release VERSION=X.Y`
