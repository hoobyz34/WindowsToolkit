# WindowsToolkit Architecture

## Purpose

WindowsToolkit is a modular Windows audit, health, and safe optimization platform.

It is designed to separate:

- Discovery
- Recommendation logic
- Data/rules
- Reporting
- User-facing modules

The toolkit should inventory and explain before making any system changes.

---

## High-Level Flow

```text
Windows System
    ↓
Core\Discovery.psm1
    ↓
Core\Recommendation.psm1 + Data\*.json
    ↓
Core\Models.psm1
    ↓
Core\Reporting.psm1
    ↓
Reports\