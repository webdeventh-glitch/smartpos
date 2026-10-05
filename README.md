# Nexus POS

Offline Windows POS and inventory workspace, rebuilt around a cashier checkout.
No sample products or fake business data are added.

## Working features

- Product search by name/SKU/barcode, category chips and product cards.
- Barcode scanner keyboard input: scan and press Enter to add a product.
- Cart quantity controls; F2 search, F4 park and F9 payment.
- Multiple SQLite-backed parked bills that survive restart.
- Fixed invoice discounts and inclusive/exclusive tax with two-decimal percentage input.
- Cash/card/bank/digital split payment allocations, with exact total validation and automatic cash change.
- Atomic invoice, stock movement and payment posting; retry-safe checkout tokens.
- Partial/full sale returns, exact cumulative refunds, restocking and immutable return history.
- Receipt preview/copy and saved invoice payment/tax/discount details.
- Product CRUD, barcode/category/cost metadata, opening stock and adjustments.
- Purchase receiving, low-stock view and immutable stock/document history.
- Desktop sidebar and compact tabbed checkout on smaller screens.

Card/digital allocations record externally collected payments; they do not charge
a payment gateway. Customer name is a receipt label, not a credit account.

## Run and build

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run -d windows
flutter build windows --release --no-pub
```

Executable: `build/windows/x64/runner/Release/desktop_starter.exe`.
Distribute the entire Release folder, including DLLs and data, not the EXE alone.

## Data and upgrades

The existing database remains `%LOCALAPPDATA%\SimpleStock\stock.db`.
SQLite v6 upgrades existing v1-v5 databases transactionally and preserves inventory
and invoices. New payment metadata is null for legacy documents: their payment
status is unknown. Close the app and copy the entire database directory to a dated
backup before upgrading. Rollback requires the older binary and pre-upgrade backup.
Tests use disposable databases and do not open your live inventory.

## Current scope

This is a rebuilt operational POS core, **not the complete commercial system in
the master brief**. Outstanding: exchanges, damaged/non-restock returns, item discounts, thermal/A4 printing, cashier shifts, customer/supplier accounts and
Khata, double-entry accounting, authentication/RBAC, automated backups, advanced
inventory, full reporting, Android packaging, branches/warehouses and cloud sync.
The app currently opens a single local store without login.

See [implementation and migration record](docs/IMPLEMENTATION.md) and
[POS operator guide](docs/POS.md) for rules, validation and remaining work.
