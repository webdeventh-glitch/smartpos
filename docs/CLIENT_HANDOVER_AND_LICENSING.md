# Smart POS System — Client Handover, Licensing & Deployment Guide

## 1. Executive Summary & Release Details
- **Product Name:** Smart POS System (Enterprise Multi-Industry Point of Sale)
- **Current Version:** 1.0.0
- **Build Target:** Windows 10/11 64-bit Native
- **Release Directory:** `build\windows\x64\runner\Release\`
- **Portable Client Package:** `dist\SmartPOS_Portable_v1.0.zip` (15.65 MB)
- **Installer Configuration:** `installer\smartpos_setup.iss`
- **One-Click Build & Packaging:** `powershell -ExecutionPolicy Bypass -File installer\build_package.ps1`

---

## 2. First-Time Run & Setup Wizard Workflow
Upon a fresh installation on a new client computer:
1. **Automatic Setup Detection:**
   The database initializes with `is_configured = 0`. The application immediately detects this and automatically launches the full-screen **Setup Wizard** (`SetupWizardScreen`).
2. **Step 1 — Business Profile:**
   - Configure Business Name, Branch Name, Phone, Email, Address.
   - Set Currency (e.g., PKR, USD, EUR), Currency Symbol, and Tax Rate.
3. **Step 2 — Business Type & Modular Features:**
   - Select primary business category:
     - 🛒 **Supermarket / FMCG Retail** (Fast barcode scanning, expiry tracking)
     - 💊 **Pharmacy & Healthcare** (Drug licenses, batch numbers, expiry alerts)
     - 🍽️ **Restaurant / Cafe** (Dining tables, Kitchen Order Tickets - KOT)
     - 🏨 **Hotel & Hospitality** (Room booking, check-in/out, room service)
     - 🏋️ **Gym & Fitness** (Member packages, trainers, locker management)
     - 🔧 **Mobile & Laptop Repair** (Job ticketing, IMEI, diagnostic tracking)
4. **Step 3 — Sync & Database Mode:**
   - Choose between **Offline SQLite Only**, **Local LAN Sync**, or **Cloud MySQL/API Sync**.
5. **Step 4 — Clean Foundation vs. Demo Data Selection:**
   - **Default (Clean Mode):** The "Seed Demo Data" checkbox is **UNCHECKED** by default.
     The software starts with **zero demo products, zero demo purchases, zero demo sales, and zero demo expenses**.
   - **Optional Demo Mode:** If the client wants to train their staff, they can check "Seed Sample Data for My Business Type". Realistic sample items tailored to their specific industry will be created.
6. **Finish & Ready:**
   Clicking **"Save & Launch Smart POS"** marks `is_configured = 1` and redirects directly to the POS Workspace and Dashboard.

---

## 3. Lazimi Foundation Data (Always Seeded)
Regardless of whether demo seeding is chosen, the database automatically includes the mandatory operational foundation:
| Foundation Item | Default Details |
|---|---|
| **Superadmin User** | Username: `superadmin` \| Password: `password` |
| **Main Location** | `Main Branch HQ` (Location ID: `BL0001`) |
| **Default Tax Rates** | `No Tax (0%)`, `Standard VAT (5%)`, `GST / Sales Tax (15%)` |
| **Invoice Schemes** | `INV-XXXX` (Prefix: `INV-`, 4 Digits) |
| **Standard Units** | `Pieces (Pc)`, `Box (12 Pcs)`, `Kilograms (Kg)`, `Liters (Ltr)` |
| **Price Groups** | `Retail Price`, `Wholesale Price`, `Special VIP Price` |
| **Cash Drawer** | `Main Store Cash Drawer` (Balance: 0.0) |
| **Primary Bank Account** | `Primary Bank Account` (Balance: 0.0) |
| **Cash Register** | Session automatically opened for cashier with 0.0 opening sales |
| **Walk-in Customer** | `Walk-in Customer` (Balance: 0.0) |

---

## 4. Hardware-Locked SaaS Licensing (Qulop Engine)

### For the Client:
1. When opening the app for the first time, a 14-day evaluation grace period begins.
2. In the **Settings -> License Activation** screen, the client will see their unique **Machine Hardware ID** (derived from CPU, Motherboard, and MAC address).
3. The client copies this Machine ID and sends it to you (Rafiq / Webdeventh).

### For the Vendor (Rafiq):
1. On your machine, double-click:
   ```cmd
   run_qulop_generator.bat
   ```
   *(Or run: `flutter run -t lib/qulop_generator_main.dart -d windows`)*
2. In the Qulop SaaS License Generator window:
   - Paste the client's **Machine Hardware ID**.
   - Enter the **Client Name** or **Business Name**.
   - Choose the license duration:
     - `TRL` - 14 Days Trial
     - `MTH` - 1 Month License
     - `QTR` - 3 Months License
     - `HLF` - 6 Months License
     - `YRL` - 1 Year License
     - `LFT` - Lifetime Perpetual License
3. Click **"Generate License Key"**.
4. Copy the generated key (e.g. `QULOP-YRL-XXXX-XXXX-XXXX`) and send it to the client.

### Client Activation:
1. Client enters the key into **Settings -> License Activation** and clicks **"Activate License"**.
2. The key is cryptographically validated and locked to their hardware.
3. The license status shows active with the expiration countdown.

---

## 5. Client Deployment Packages
You have two delivery options for clients:

### Option A: Portable Zero-Install (Recommended for Instant Use)
- **File:** `dist\SmartPOS_Portable_v1.0.zip`
- **Installation:**
  1. Extract `SmartPOS_Portable_v1.0.zip` to `C:\SmartPOS\` or any folder/USB drive.
  2. Double-click `Start_SmartPOS.bat` (or `pos.exe`).
  3. No administrative privileges required.

### Option B: Windows Inno Setup Installer (.exe)
- **Script:** `installer\smartpos_setup.iss`
- **Compilation:**
  Run `powershell -ExecutionPolicy Bypass -File installer\build_package.ps1`.
  If Inno Setup 6 is installed, it automatically compiles `dist\SmartPOS_Setup_v1.0.exe`.
- Installs to `C:\Program Files\SmartPOS` with Desktop & Start Menu shortcuts.

---

## 6. Verification & Test Summary
- **Test Suite:** 25 test files, **68 out of 68 tests PASSED (100%)**.
- **Code Analysis:** **0 Errors, 0 Warnings**.
- **Database Stress Benchmark:** 10,000 transactions inserted at **35,842 tx/sec**.
- **Memory & Storage:** Ultra-fast startup, SQLite WAL mode, pure native performance.
