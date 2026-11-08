TRUNCATE TABLE
    order_payments,
    order_items,
    dine_in_order_details,
    online_order_details,
    takeaway_order_details,
    delivery_dispatches,
    orders,
    daily_calculations,
    data_sync_logs,
    processed_operations,
    system_change_logs
RESTART IDENTITY CASCADE;

