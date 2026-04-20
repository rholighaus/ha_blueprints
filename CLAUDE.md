# ha_blueprints — Claude Code Context

## What this repo is
Home Assistant automation blueprints for the property at The Grange Bourton.
Blueprints are stored on Home Assistant and mirrored here on GitHub.

## Key files to read on startup
Before answering any questions or making any changes, always read these files
to get the full current state of the project:

```
blueprints/automation/charge-powerwall-when-throttling.yaml
blueprints/automation/Goodwe g100 throttle.yaml
blueprints/automation/goodwe_g100_throttle_v2.yaml
blueprints/automation/powerwall-octopus-go-cheap-charging.yaml
blueprints/automation/warp-solar-excess-charging.yaml
blueprints/automation/Vesternet 8 Button Zigbee Wall Controller z2m.yaml
```

These files are the source of truth for all blueprint logic, entity names,
inputs, and version history. Do not rely on memory — read them directly.

For GoodWe throttling logic specifically:
- `Goodwe g100 throttle.yaml` — single inverter (Phases A and B)
- `goodwe_g100_throttle_v2.yaml` — dual inverter proactive feed-forward (Phase C)

## Repository structure
```
~/development/ha_blueprints/          ← repo root
├── Makefile
├── CLAUDE.md
└── blueprints/
    └── automation/
        ├── charge-powerwall-when-throttling.yaml       v1.2
        ├── Goodwe g100 throttle.yaml                   v1.0
        ├── goodwe_g100_throttle_v2.yaml
        ├── powerwall-octopus-go-cheap-charging.yaml
        ├── Vesternet 8 Button Zigbee Wall Controller z2m.yaml
        └── warp-solar-excess-charging.yaml
```

## Home Assistant access
- SSH alias: `homeassistant`
- Blueprint path on HA: `/config/blueprints/automation/rholighaus/`
- HA version: 2026.4.2
- HA token stored at: `~/.ha_token`
- HA REST API base: `http://homeassistant:8123`
- HA MCP is connected — use it for automation/entity management

## Key entities
### GoodWe throttling dispatch switches (input_boolean)
- Phase A: `input_boolean.goodwe_phase_a_throttling_active`
- Phase B: `input_boolean.goodwe_phase_b_throttling_active`
- Phase C: `input_boolean.goodwe_phase_c_throttling_active`

### GoodWe current limit helpers (input_number, 0–1000 permille)
- Phase A: `input_number.goodwe_phase_a_current_limit_permille`
- Phase B: `input_number.goodwe_phase_b_current_limit_permille`
- Phase C: `input_number.goodwe_phase_c_current_limit_permille`

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
- Next rate: `sensor.octopus_energy_electricity_25j0223825_2000012019734_next_rate`
- Cheap (Octopus Go) rate is ~0.052 GBP/kWh, active 23:30–05:30
- Cheap rate detection: `current_rate <= current_day_min_rate attribute`

### Notifications
- Ralf's iPhone: `notify.mobile_app_ralfs_iphone`

### GoodWe shell commands (in configuration.yaml)
- Phase A: `shell_command.goodwe_set_power_phase_a`
- Phase B: `shell_command.goodwe_set_power_phase_b`
- Phase C (v1): `shell_command.goodwe_set_power_phase_c`
- Phase C 10kW (v2): `shell_command.goodwe_set_power_phase_c_10k`
- Phase C 6kW (v2): `shell_command.goodwe_set_power_phase_c_6k`

## Active automations created in this project
- `automation.grange_a_charge_powerwall_when_throttling` — blueprint instance, Phase A
- `automation.grange_b_charge_powerwall_when_throttling` — blueprint instance, Phase B
- `automation.grange_c_charge_powerwall_when_throttling` — blueprint instance, Phase C
- `automation.powerwall_backup_reserve_periodic_safety_reset` — standalone, every 30 min + HA start
- `automation.octopus_go_tesla_optimisation` — Octopus Go nighttime charging (alias: "Octopus Go Tesla Nighttime Charging")

## Blueprint inventory
| File | Version | Purpose |
|------|---------|---------|
| `charge-powerwall-when-throttling.yaml` | 1.2 | Raises/restores Powerwall backup reserve when GoodWe throttling is active. Skips if battery already full. |
| `Goodwe g100 throttle.yaml` | 1.0 | G100 export throttle for single GoodWe inverter phases (A and B). Reactive, ramps down on over-limit, instant release. |
| `goodwe_g100_throttle_v2.yaml` | — | Proactive dual-inverter throttle for Phase C (10kW + 6kW GoodWe). Gradual ramp in both directions. |
| `powerwall-octopus-go-cheap-charging.yaml` | — | Charges Powerwalls from grid during Octopus cheap rate window |
| `Vesternet 8 Button Zigbee Wall Controller z2m.yaml` | — | Z2M event handler for Vesternet 8-button controller |
| `warp-solar-excess-charging.yaml` | — | WARP EV charger solar-excess charging control |

## Blueprint conventions
- All blueprints MUST have `source_url` pointing to this GitHub repo
  - Required by `blueprints_updater` custom component — blueprints without it are silently ignored
- URL format: `https://github.com/rholighaus/ha_blueprints/blob/main/blueprints/automation/<filename>`
- Spaces in filenames must be encoded as `%20` in the URL
- Version is tracked in the `description` field as `**Version: X.Y**`
- `source_url: null` is rejected by HA 2026.4 — omit or use a real URL
- Optional entity inputs must use bare `default:` not `default: null`
- Files must use Unix line endings (LF not CRLF)

## Important quirks discovered
- `blueprints_updater` custom component silently ignores blueprints without a valid `source_url`
- HA 2026.4 rejects `source_url: null`
- SCP/SFTP is disabled on the SSH add-on (`"sftp": false`) — cannot push files via scp/sftp
- Files can be written to HA via: `curl` POST to `shell_command.goodwe_set_power_phase_a` with base64-encoded content
- Files can be read from HA via: `ssh homeassistant "cat /path/to/file"`
- `sync-to-ha` Makefile target uses the HA REST API with token from `~/.ha_token`

## Makefile targets
```bash
make push                    # git add . && commit && push to GitHub
make pull-from-ha            # pull all blueprints from HA → Mac
make sync-to-ha              # push all blueprints Mac → HA (uses ~/.ha_token + REST API)
make reload-ha               # trigger homeassistant.reload_all via REST API
make deploy                  # push + sync-to-ha
make bump-version VERSION=1.1                        # bump version in ALL blueprints
make bump-file FILE="name.yaml" VERSION=1.2          # bump version in ONE blueprint
make release-file FILE="name.yaml" VERSION=1.2       # bump + commit + push + tag + sync to HA
make release VERSION=1.1                             # bump all + push + tag + sync to HA
```

## Workflow
**Edit on Mac → deploy to GitHub + HA:**
```bash
make release-file FILE="charge-powerwall-when-throttling.yaml" VERSION=1.3
```

**Edit on HA (File Editor) → sync back to Mac + GitHub:**
```bash
make pull-from-ha
make push
```

**Full release of all blueprints:**
```bash
make release VERSION=2.0
```

## GitHub repo
- URL: https://github.com/rholighaus/ha_blueprints
- Branch: main
- Tags follow pattern: `vX.Y-blueprint-stem` (single file) or `vX.Y` (all files)
- SSH key authentication configured on Mac
