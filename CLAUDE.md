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

## Home Assistant GoodWe G100 Throttle Blueprint

**Blueprint location:** `blueprints/automation/rholighaus/goodwe_g100_throttle.yaml`

### Architecture
- Three phases (A/B/C), each with a GoodWe 10kW inverter controlled via Modbus TCP
- Each phase also has an uncontrolled 6kW FoxESS inverter (to be replaced with GoodWe 6kW later)
- Control script: `/config/scripts/goodwe_reg.py <host> write 45484 <value>`
- Register 45484 = Active Power limit in permille (0-1000, where 1000 = 100%)

### Inverter IPs and entities
| Phase | IP | GoodWe 10k PV sensor | Grid sensor | Solar CT clamp |
|-------|-----|----------------------|-------------|----------------|
| A | 10.27.1.105 | sensor.goodwe_10k_phase_1_pv_power_total | sensor.grid_phase_a_power | sensor.solar_a_power |
| B | 10.27.1.106 | sensor.goodwe_10k_phase_2_pv_power_total | sensor.grid_phase_b_power | sensor.solar_b_power |
| C | 10.27.1.107 | sensor.goodwe_10k_phase_3_pv_power_total | sensor.grid_phase_c_power | sensor.solar_c_power |

### Key helpers
- `input_number.goodwe_phase_{a,b,c}_current_limit_permille` — tracks current throttle state
- `input_boolean.goodwe_phase_{a,b,c}_throttle_enable` — enable/disable per phase
- `input_boolean.goodwe_phase_{a,b,c}_throttling_active` — load dispatch signal
- `timer.goodwe_phase_{a,b,c}_dispatch_release_timer` — 15 min release delay

### Known issues / important notes
- `goodwe_active` check MUST use `solar_power_sensor` (CT clamp), NOT `pv_power_sensor`
  Reason: pv_power_total drops to near zero when throttled, causing a feedback loop
  (goodwe_active → False → release to 1000‰ → spike → throttle → repeat)
- solar_b_power CT clamp is physically wired in reverse — blueprint uses `| abs` to handle this
- G100 per-phase export limit: 7000W
- shell_command entries in configuration.yaml:
    goodwe_set_power_phase_a: "python3 /config/scripts/goodwe_reg.py 10.27.1.105 write 45484 {{ value }}"
    goodwe_set_power_phase_b: "python3 /config/scripts/goodwe_reg.py <IP_B> write 45484 {{ value }}"
    goodwe_set_power_phase_c: "python3 /config/scripts/goodwe_reg.py <IP_C> write 45484 {{ value }}"
