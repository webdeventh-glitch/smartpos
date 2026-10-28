# Smart POS Enterprise (Enterprise ERP & Point of Sale System)

## Overview & Architecture
The system is built on **Flutter Desktop / Web** with a local, offline-capable **SQLite** database initialized via `sqflite_common_ffi` and hybrid synchronization with MySQL.

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
- Database path: `%LOCALAPPDATA%/SmartPOS/smart_pos.db`.
- Atomic transactional checkout:
  - Generates serial invoice numbers (`INV-1001`, `INV-1002`, ...).
  - Deducts product stock atomically.
  - Updates customer balance when partial/credit sales occur.
  - Updates active cash register sales balances in real-time.
- Rich seed data: retail products, categories, brands, customers, suppliers, expenses, and active register session.

---

### 3. User Interface & Screens

| Module | File | Features |
|---|---|---|
| **Shell & Layout** | `lib/screens/main_shell.dart` | Master layout coordinating gradient header bar and collapsible dark navigation sidebar. |
| **Header Bar** | `lib/widgets/smart_app_bar.dart` | Store selector, live digital clock, cash in hand indicator, quick calculator, POS launch button, cashier profile. |
| **Sidebar** | `lib/widgets/smart_sidebar.dart` | Collapsible sidebar with active icons for all ERP modules and offline status badge. |
| **Home Dashboard** | `lib/screens/dashboard/dashboard_screen.dart` | Financial KPI stat cards, sales vs purchases chart (`fl_chart`), category breakdown, stock alert warnings, recent sales. |
| **POS Terminal** | `lib/screens/pos/pos_terminal_screen.dart` | Fast barcode scanning, quantity steppers, cart discounts, taxes, quick cash denominations, split payment modal, suspended cart drawer. |
| **Thermal Receipt** | `lib/screens/pos/receipt_dialog.dart` | Authentic 80mm thermal receipt layout with store header, itemized table, taxes, tenders, barcode, and print action. |
| **Products & Catalog** | `lib/screens/products/products_list_screen.dart` | Search, filter, inventory valuation, stock status badges, add/edit/delete product dialogs. |
| **Purchases & Restocking**| `lib/screens/purchases/purchases_list_screen.dart` | Add purchase receiving, automatic stock increments, vendor payables. |
| **Contacts CRM** | `lib/screens/contacts/` | Dedicated customer and supplier directories with ledger balances. |
| **Expenses** | `lib/screens/expenses/expenses_screen.dart` | Track store operating costs (rent, utilities, salaries, refreshments). |
| **Reports** | `lib/screens/reports/reports_screen.dart` | Multi-dimensional reports (P&L statement, COGS, gross profit, net margin, stock valuation, dues). |
| **Settings** | `lib/screens/settings/settings_screen.dart` | Configurable currency symbol, tax rates, store information, and receipt footer. |

---

## Verification & Test Results
- `flutter analyze`: **0 issues found** across all files.
- `flutter test test/smart_pos_core_test.dart test/smart_pos_widget_test.dart`: **All tests passing**.
