# Ultimate POS (Enterprise ERP & Point of Sale System)

## Overview & Complete Redesign
As per user requirements, the codebase has been redesigned from scratch to implement the full enterprise UI, workflow, and architecture of **Ultimate POS** (matching https://pos.ultimatefosters.com/home).

The system is built on **Flutter Desktop / Web** with a local, offline-capable **SQLite** database (`ultimate_pos.db`) initialized via `sqflite_common_ffi`.

---

## Architecture & Modules

### 1. Data Models (`lib/models/models.dart`)
- **`BusinessSettings`**: Store profile, branch name, currency symbol, default tax rates, phone, physical address, invoice prefix, receipt footer.
- **`Category` & `Brand`**: Product taxonomies with codes and descriptions.
- **`Product`**: SKU, Barcode, Name, Unit, Wholesale Cost Price, Retail Selling Price, Stock Quantity, Alert Threshold, Color representation.
- **`Contact`**: Customer & Supplier profiles, addresses, credit limits, and balances.
- **`Sale` & `SaleItem`**: Invoices, customer links, subtotal, discount, order taxes, shipping, payment methods, payment status, sale status (final, draft, quotation, suspended).
- **`Purchase`**: Supplier bills, unit cost, quantities, automatic stock incrementation, and payable balances.
- **`Expense`**: Operating expense logs with categories, reference numbers, and notes.
- **`CashRegister`**: Shift sessions, cash in hand at open, total cash sales, card sales, and closing balance reconciliations.
- **`ParkedSale`**: Suspended cart sessions allowing cashiers to hold and resume orders without holding the line.

---

### 2. SQLite Database & Storage Engine (`lib/services/database_service.dart`)
- Database path: `%LOCALAPPDATA%/UltimatePOS/ultimate_pos.db`.
- Atomic transactional checkout:
  - Generates serial invoice numbers (`INV-1001`, `INV-1002`, ...).
  - Deducts product stock atomically.
  - Updates customer balance when partial/credit sales occur.
  - Updates active cash register sales balances in real-time.
- Rich seed data: 10+ retail products (beverages, groceries, electronics, apparel, personal care), categories, brands, customers, suppliers, expenses, and active register session.

---

### 3. User Interface & Screens

| Module | File | Features |
|---|---|---|
| **Shell & Layout** | `lib/screens/main_shell.dart` | Master layout coordinating gradient header bar and collapsible dark navigation sidebar. |
| **Header Bar** | `lib/widgets/ultimate_app_bar.dart` | Store selector, live digital clock, cash in hand indicator, quick calculator, POS launch button, cashier profile. |
| **Sidebar** | `lib/widgets/ultimate_sidebar.dart` | Collapsible sidebar with active icons for all 10 ERP modules and offline status badge. |
| **Home Dashboard** | `lib/screens/dashboard/dashboard_screen.dart` | 8 financial KPI stat cards, sales vs purchases chart (`fl_chart`), category breakdown, stock alert warnings, recent sales. |
| **POS Terminal** | `lib/screens/pos/pos_terminal_screen.dart` | Fast barcode scanning, quantity steppers, cart discounts, taxes, quick cash denominations, split payment modal, suspended cart drawer. |
| **Thermal Receipt** | `lib/screens/pos/receipt_dialog.dart` | Authentic 80mm thermal receipt layout with store header, itemized table, taxes, tenders, barcode, and print action. |
| **Products & Catalog** | `lib/screens/products/products_list_screen.dart` | Search, filter, inventory valuation, stock status badges, add/edit/delete product dialogs. |
| **Purchases & Restocking**| `lib/screens/purchases/purchases_list_screen.dart` | Add purchase receiving, automatic stock increments, vendor payables. |
| **Contacts CRM** | `lib/screens/contacts/` | Dedicated customer and supplier directories with ledger balances. |
| **Expenses** | `lib/screens/expenses/expenses_screen.dart` | Track store operating costs (rent, utilities, salaries, refreshments). |
| **Reports** | `lib/screens/reports/reports_screen.dart` | Profit & Loss statement (COGS, gross profit, net margin) and stock audit. |
| **Settings** | `lib/screens/settings/settings_screen.dart` | Configurable currency symbol, tax rates, store information, and receipt footer. |

---

## Verification & Test Results
- `flutter analyze`: **0 issues found** across all files.
- `flutter test test/ultimate_pos_test.dart test/ultimate_pos_widget_test.dart`: **All 8 tests passing** (schema, transactions, inventory adjustments, UI rendering).
