# Base Role

System preparation and foundational setup for Ubuntu.

## Purpose

Prepares the system for subsequent configuration by:
- Updating apt cache
- Installing essential packages
- Configuring timezone and locale
- Creating required directories

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `timezone` | `Europe/Berlin` | System timezone |
| `locale` | `en_US.UTF-8` | System locale |

## Tags

- `base` - All base tasks

## Dependencies

None - this is the first role to run.
