"""Cash transaction event handlers.

NOTE: Cash recording is handled directly within SalesService,
PurchaseService, PaymentService, and ExpenseService (which call
CashService.record_cash_in/record_cash_out) inside the same
database transaction. This ensures atomicity.

Event-driven cash handling was an earlier design that was superseded
by direct service calls. These handlers are NOT registered in the event bus.
"""
