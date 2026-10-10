# SMART Referral - Central Authoritative Backend & Device Sync

This service provides a centralized authoritative backend and incremental synchronization engine for the SMART Referral healthcare platform.

## Architecture
```
Flutter Clients (Web / Android / Windows)
         │  (HTTP REST / JSON Sync)
         ▼
Central API Handler (`backend/server.py`)
         │
Database Layer (`backend/database.py`)
         │
Authoritative SQLite Database (`backend/central_healthcare.db`)
```

## Features
- **Authoritative Database:** Stores all healthcare facilities, clinical capabilities, verification records, time-sensitive operational status, and audit logs.
- **Incremental Device Synchronization:** Supports `/api/v1/sync/pull?since_revision=<rev>` cursor tracking.
- **Queue & Batch Push:** Supports `/api/v1/sync/push` with idempotency keys and revision conflict checks.
- **Freshness Monitoring:** Enforces 30-minute operational data TTL to prevent stale bed/ICU availability from misleading emergency decisions.
- **Zero-Dependency:** Runs on any standard Python 3.10+ runtime without external packages.

## Quick Start
```bash
# Start backend server on port 8000
python backend/server.py
```

## API Endpoints
- `GET  /api/v1/health` - Service health status
- `GET  /api/v1/facilities` - Filterable facility list (supports query, specialty, tag, emergency_only)
- `GET  /api/v1/facilities/<id>` - Single facility by ID
- `PUT  /api/v1/facilities/<id>/status` - Update operational availability (beds, ICU, capacity)
- `GET  /api/v1/sync/pull` - Incremental sync download since cursor revision
- `POST /api/v1/sync/push` - Batch sync upload with idempotency
- `GET  /api/v1/audit-logs` - Query audit history
- `GET  /api/v1/roles` - View roles and permissions
