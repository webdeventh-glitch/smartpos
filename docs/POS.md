# POS operator guide

1. Open Products and register products with stock and selling prices. Existing
   products are available automatically; barcode and category are optional.
2. Open Point of sale. Click a product, search a name/SKU prefix, or scan a barcode
   followed by Enter. Search shows a bounded 200-result page; refine the search.
3. Adjust quantities with plus/minus. Minus on quantity one removes the line.
4. Optionally enter a customer name, fixed rupee discount and tax rate.
   Tax applies after invoice discount. Rates accept two decimal places (17.50%).
   Tax rounds half up once per invoice; all amounts are integer paisa.
5. Charge (F9), enter tender amounts, check change, then Complete sale.
   Card/bank/digital settlement occurs outside this app. No partial credit sale.
6. Copy the receipt or start another sale. Sales history retains the invoice,
   discount/tax and payments. Posted financial records cannot be edited/deleted.
7. Park (F4) to save a draft before starting another bill. The clock button lists
   parked bills. Resume requires an empty current cart. A resumed draft stays in
   the database until checkout commits, preventing loss on restart. Unparked
   current carts are memory-only. Park before closing the app.

Stock is not reserved by a parked bill. Availability is rechecked transactionally
at checkout. An entire checkout rolls back if any line is unavailable. Retry of
an identical operation token returns the saved invoice; changed payloads reject.
A sale saves its prices, quantities and product names as historical snapshots.

Purchases receive inventory using the existing multi-item purchase form. This is
receiving only, without supplier payment/approval or cost-accounting automation.

No printer, cash drawer, payment gateway, RBAC or remote service is configured.
Receipt copy is text; it is not a thermal printing implementation. Inventory
reference costs are not FIFO/weighted-average accounting valuation.


## Cash change and inclusive tax (phase 2 increment)

Enable **Prices include tax** when catalog prices already contain tax. Invoice
discounts reduce the gross amount first; included tax is extracted from that
amount using rate / (100 + rate), rounded half up to the nearest paisa once per
invoice. Exclusive mode continues adding tax after the discount. Parking preserves
this selection; older parked bills default to exclusive mode.

In Collect payment, enter cash received and externally collected non-cash amounts.
The dialog shows the remaining amount or change live. For a Rs 100 bill with
Rs 40 card and Rs 100 cash received, the recorded allocations are Rs 40 card and
Rs 60 cash, with Rs 40 change. Non-cash overpayments are rejected. When no cash
is due, cash received must be zero. Receipts and invoice history show cash received
and change. No payment gateway is called.

SQLite v5 adds nullable tax-mode/tender/change metadata, preserving old documents
without inventing historical tender. Existing v4 retry payloads remain compatible
when using the previous exact-payment/exclusive-tax behavior.


## Sale returns

Open Sales history, select a sale, then **Return items**. Enter quantities or use
**Return all remaining**, enter a reason, choose the externally arranged refund
method, review the refund and select **Record return**. This records the refund;
it does not issue a card/bank transfer. Returned units go back into sellable stock.
The sale details show return references, items, quantities, reasons, methods,
refund amounts and net sale after refunds. The sales-list headline is gross sales
before refunds.

Refunds use the original paid invoice total, including its discount and tax.
That total is allocated proportionally to original line values in saved line
order, using cumulative integer division. Within each line, successive returns
receive the difference between cumulative entitlements. This preserves every
paisa: returning all units refunds exactly the original total. The last returned
units may differ by a paisa. Free items can be restocked with a zero refund.

Each return, its lines and stock movements commit atomically. Duplicate retries
are safe; changed retry payloads and excess quantities reject. Deleted products
and stock-limit overflow reject the entire return. Old sales without known POS
payment metadata cannot use automatic refunds. Original invoices/payments remain
unchanged. Return records survive restart and cannot be edited or deleted.

Exchanges, non-restock/damaged returns, refund gateway integration and tax credit
note printing are not implemented. SQLite v6 adds return tables without rewriting
historical sales. Back up the closed database directory before deploying upgrades.
