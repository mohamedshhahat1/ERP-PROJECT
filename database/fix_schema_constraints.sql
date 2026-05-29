-- ============================================================
-- Schema Improvements: Constraints, Indexes, and Data Integrity
-- Run this as a migration on existing databases.
-- For new installs, these are also added to schema.sql.
-- ============================================================

-- #24: Add UNIQUE constraint on purchase_invoices.invoice_number
ALTER TABLE purchase_invoices
    ADD CONSTRAINT uq_purchase_invoices_number UNIQUE (invoice_number);

-- #25: Link expenses.expense_category to expense_categories table via FK
-- First add a category_id column, then backfill from expense_categories
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS expense_category_id INTEGER;

-- Backfill existing data (match by name)
UPDATE expenses e
SET expense_category_id = ec.category_id
FROM expense_categories ec
WHERE ec.name = e.expense_category;

-- Add FK constraint (using NOT VALID to avoid blocking on large tables)
ALTER TABLE expenses
    ADD CONSTRAINT fk_expenses_category
    FOREIGN KEY (expense_category_id) REFERENCES expense_categories(category_id)
    NOT VALID;

-- #26: Add CHECK constraints on quantities and payment amounts
ALTER TABLE sales_invoice_items
    ADD CONSTRAINT chk_sold_quantity_positive CHECK (sold_quantity > 0);

ALTER TABLE purchase_invoice_items
    ADD CONSTRAINT chk_purchased_quantity_positive CHECK (purchased_quantity > 0);

ALTER TABLE customer_payments
    ADD CONSTRAINT chk_customer_payment_positive CHECK (payment_amount > 0);

ALTER TABLE supplier_payments
    ADD CONSTRAINT chk_supplier_payment_positive CHECK (payment_amount > 0);

ALTER TABLE expenses
    ADD CONSTRAINT chk_expense_amount_positive CHECK (amount > 0);

ALTER TABLE warehouse_transfers
    ADD CONSTRAINT chk_transfer_quantity_positive CHECK (quantity > 0);

ALTER TABLE waste
    ADD CONSTRAINT chk_waste_quantity_positive CHECK (quantity > 0);

-- Discount cannot exceed total
ALTER TABLE sales_invoices
    ADD CONSTRAINT chk_discount_not_exceed_total CHECK (discount_amount >= 0 AND discount_amount <= total_amount);

-- #27: Add missing indexes for common query patterns
-- Ledger entries by date (for date-range financial queries)
CREATE INDEX IF NOT EXISTS idx_ledger_entries_date
    ON ledger_entries(entry_date);

-- Sales invoices by payment status (for unpaid/partial queries)
CREATE INDEX IF NOT EXISTS idx_sales_invoices_payment_status
    ON sales_invoices(payment_status);

-- Purchase invoices by payment status
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_payment_status
    ON purchase_invoices(payment_status);

-- Composite index for unread notifications per user (most common query)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Functional index for date-only queries on sales (used in financial summaries)
CREATE INDEX IF NOT EXISTS idx_sales_invoices_date_only
    ON sales_invoices((invoice_date::date));

-- Functional index for date-only queries on expenses
CREATE INDEX IF NOT EXISTS idx_expenses_date_only
    ON expenses((expense_date::date));

-- Purchase invoices by date
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date
    ON purchase_invoices(purchase_date);

-- #29: Add FK constraints on created_by columns
ALTER TABLE inventory_transactions
    ADD CONSTRAINT fk_inventory_transactions_created_by
    FOREIGN KEY (created_by) REFERENCES users(user_id)
    NOT VALID;

ALTER TABLE cash_transactions
    ADD CONSTRAINT fk_cash_transactions_created_by
    FOREIGN KEY (created_by) REFERENCES users(user_id)
    NOT VALID;

ALTER TABLE expenses
    ADD CONSTRAINT fk_expenses_created_by
    FOREIGN KEY (created_by) REFERENCES users(user_id)
    NOT VALID;

ALTER TABLE ledger_entries
    ADD CONSTRAINT fk_ledger_entries_created_by
    FOREIGN KEY (created_by) REFERENCES users(user_id)
    NOT VALID;

-- #30: Replace day-by-day loop with set-based financial summary refresh
CREATE OR REPLACE FUNCTION fn_refresh_financial_summary_range(p_start_date DATE, p_end_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
    -- Set-based approach: compute all days at once instead of looping
    INSERT INTO daily_financial_summary (summary_date, revenue, cogs, gross_profit, expenses, net_profit, sales_count, returns_amount, last_updated)
    SELECT
        d.day_date,
        COALESCE(s.revenue, 0),
        COALESCE(s.cogs, 0),
        COALESCE(s.revenue, 0) - COALESCE(s.cogs, 0),
        COALESCE(e.total_expenses, 0),
        (COALESCE(s.revenue, 0) - COALESCE(s.cogs, 0)) - COALESCE(e.total_expenses, 0),
        COALESCE(s.sales_count, 0),
        COALESCE(r.returns_amount, 0),
        NOW()
    FROM generate_series(p_start_date, p_end_date, '1 day'::interval) AS d(day_date)
    LEFT JOIN LATERAL (
        SELECT
            SUM(sii.total_price) AS revenue,
            SUM(sii.sold_quantity * sii.cost_at_sale) AS cogs,
            COUNT(DISTINCT si.invoice_id) AS sales_count
        FROM sales_invoice_items sii
        JOIN sales_invoices si ON si.invoice_id = sii.invoice_id
        WHERE si.invoice_date::date = d.day_date::date
    ) s ON TRUE
    LEFT JOIN LATERAL (
        SELECT SUM(amount) AS total_expenses
        FROM expenses
        WHERE expense_date::date = d.day_date::date
    ) e ON TRUE
    LEFT JOIN LATERAL (
        SELECT SUM(returned_amount) AS returns_amount
        FROM sales_returns
        WHERE return_date::date = d.day_date::date
    ) r ON TRUE
    ON CONFLICT (summary_date) DO UPDATE SET
        revenue = EXCLUDED.revenue,
        cogs = EXCLUDED.cogs,
        gross_profit = EXCLUDED.gross_profit,
        expenses = EXCLUDED.expenses,
        net_profit = EXCLUDED.net_profit,
        sales_count = EXCLUDED.sales_count,
        returns_amount = EXCLUDED.returns_amount,
        last_updated = NOW();
END;
$$ LANGUAGE plpgsql;
