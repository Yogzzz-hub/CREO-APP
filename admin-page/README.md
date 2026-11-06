# CREO Admin Page

Standalone admin dashboard. One static HTML file, no build step, no dependencies.
It only calls existing backend endpoints and changes no backend code.

## Endpoints used

- `POST /api/v1/auth/login`: sign in, returns `access_token`
- `GET /api/v1/admin/kpis?timeframe=7d|30d|90d|365d`: MRR, active clients, churn, turnaround

## Run

Serve the folder on a port the backend already allows in `CORS_ORIGINS` (for example 3000):

```bash
cd admin-page
python -m http.server 3000
```

Open http://localhost:3000, set the API base URL, and sign in with an admin account.
The token is kept in `sessionStorage` and cleared on log out.
