"""Two handlers on the same method and path: only the first ever runs, so the second is dead code that
could silently take over (with different permission checks) if the first is moved or deleted."""

from collections import Counter

from fastapi.routing import APIRoute

from app.routers import admin


def test_admin_routes_are_unique():
    keys = Counter(
        (method, route.path)
        for route in admin.router.routes
        if isinstance(route, APIRoute)
        for method in route.methods
    )
    duplicates = sorted(key for key, count in keys.items() if count > 1)
    assert duplicates == []


def test_admin_router_names_every_model_it_uses():
    # The BDE proposal ownership check queries Lead; a missing import made it crash with NameError.
    assert admin.Lead.__tablename__ == "bde_leads"
