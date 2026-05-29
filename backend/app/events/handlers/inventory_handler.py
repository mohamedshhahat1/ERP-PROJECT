"""Inventory event handlers.

NOTE: Inventory recording is handled directly within SalesService and
PurchaseService (which call InventoryService.record_sale/record_purchase)
inside the same database transaction. This ensures atomicity.

Event-driven inventory handling was an earlier design that was superseded
by direct service calls. These handlers are retained as documentation
of the event types but are NOT registered in the event bus.
"""
