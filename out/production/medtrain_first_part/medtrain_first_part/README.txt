
# First Part Delivery — Fast Path

## 0) Prereqs
- Docker + Docker Compose
- Node.js (optional, for serving static HTML)

## 1) Start DB + REST + Adminer
```bash
cd medtrain_first_part
docker compose up -d
# Wait until medtrain_rest and medtrain_db are healthy
```

- REST API: http://localhost:3000
  - `GET /risk`
  - `GET /skill`
  - `GET /training_material`
  - `GET /risk_traceability`
- Adminer: http://localhost:8080 (System: PostgreSQL, Server: db, User: demo, Password: demo, DB: medtrain)

## 2) Open the live prototype
Use a static server to avoid file:// CORS:
```bash
npx http-server . -p 5173
# then open http://localhost:5173/medtrain_first_part/simple-interface-prototype-fetch.html
```

## 3) What to demo tomorrow
- Show the Risks table loading from PostgREST (live DB).
- Show "Checks & Reports" area printing `risk_traceability` view.
- In Adminer, add a new link (risk_skill) and refresh the page to prove end-to-end link works.

## 4) Useful PostgREST queries (curl)
```bash
curl "http://localhost:3000/risk?select=code,title,severity&severity=gte.4"
curl "http://localhost:3000/risk_traceability"
```

## 5) Notes
- The DB schema + seed are in db-init/00_schema_seed.sql and were auto-run on first boot.
- You can extend with more columns or add RLS later; for the first delivery, this setup is sufficient.
