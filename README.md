# ONIMTA Mobile POS System

A production-ready commercial Android POS application built with **Flutter**, optimized for POS terminals and tablets with a primary **1280×720 landscape display** while maintaining responsiveness on smaller Android screens (800×480, 1024×600, 720×1280). Fully compatible with **Android 5.0 Lollipop (API 21+)** and above.

---

## 🏛️ Clean Architecture & SOLID OOP Design

The codebase enforces strict separation of concerns, repository abstraction, dependency injection, and clean boundaries between UI widgets, controllers, services, repositories, and SQLite data sources.

```text
lib/
├── main.dart                               # Composition root & Dependency Injection
│
├── app/
│   ├── app.dart                            # MaterialApp setup & Theme injection
│   ├── routes/
│   │   ├── app_routes.dart                 # Named route constants (/login, /pos, /more, etc.)
│   │   └── route_generator.dart            # Central RouteGenerator with fast fade transitions
│   │
│   ├── theme/
│   │   ├── app_theme.dart                  # Sharp POS ThemeData (no rounded cards)
│   │   ├── app_colors.dart                 # High-contrast commercial & Metro tile colors
│   │   ├── app_text_styles.dart            # High-visibility typography
│   │   └── app_dimensions.dart             # Standard POS touch targets (≥48dp)
│   │
│   └── constants/
│       ├── app_constants.dart              # Currency symbols, default payment methods
│       └── database_constants.dart         # SQLite table and column names
│
├── core/
│   ├── database/
│   │   ├── database_helper.dart            # Singleton SQLite connection & transactions
│   │   ├── database_initializer.dart       # Cross-platform SQLite engine init
│   │   └── database_migrations.dart        # Table DDL, indices, & initial seed data
│   │
│   ├── services/
│   │   ├── authentication_service.dart     # PIN verification & current user session
│   │   ├── database_service.dart           # Database abstraction interface
│   │   └── connectivity_service.dart       # Local-first indicator
│   │
│   ├── utils/
│   │   ├── currency_formatter.dart         # High-precision currency & quantity formatters
│   │   ├── validators.dart                 # Input validation helpers
│   │   └── responsive_helper.dart          # Breakpoints & screen adaptation (1280x720)
│   │
│   └── exceptions/
│       └── app_exceptions.dart             # Central AppException hierarchy
│
├── data/
│   ├── models/
│   │   ├── user_model.dart                 # User entity & role model
│   │   ├── product_model.dart              # Product item model (code, barcode, cost, price)
│   │   ├── customer_model.dart             # Customer model (name, phone, email, address)
│   │   ├── sale_model.dart                 # Sale header model (invoice, totals, status)
│   │   ├── sale_item_model.dart            # Sale line item model (qty, price, total)
│   │   └── pos_setting_model.dart          # POS configuration key-value model
│   │
│   ├── repositories/
│   │   ├── user_repository.dart
│   │   ├── product_repository.dart
│   │   ├── customer_repository.dart
│   │   ├── sales_repository.dart
│   │   └── settings_repository.dart
│   │
│   └── datasources/local/
│       ├── user_local_datasource.dart
│       ├── product_local_datasource.dart
│       ├── customer_local_datasource.dart
│       ├── sales_local_datasource.dart
│       └── settings_local_datasource.dart
│
├── features/
│   ├── authentication/
│   │   ├── screens/login_screen.dart       # PIN login screen with Numeric Keypad
│   │   ├── widgets/numeric_keypad.dart     # Reusable touch keypad (no Android soft-keyboard)
│   │   └── controllers/login_controller.dart
│   │
│   ├── pos/
│   │   ├── screens/
│   │   │   ├── pos_screen.dart             # Primary 1280x720 billing table view
│   │   │   ├── payment_screen.dart         # Payment checkout & cash change calculator
│   │   │   └── bill_detail_screen.dart     # Invoice summary & receipt view
│   │   ├── widgets/
│   │   │   ├── pos_header.dart             # Session bar & quick action buttons
│   │   │   ├── cart_table.dart             # Billing table with fixed header
│   │   │   ├── cart_item_row.dart          # Row item with interactive qty/price edit
│   │   │   ├── pos_summary.dart            # Subtotal, discount, items, & grand total
│   │   │   └── more_button.dart            # Bottom MORE action strip
│   │   └── controllers/pos_controller.dart # Cart state, line calculations, hold/resume bills
│   │
│   ├── more/
│   │   ├── screens/more_screen.dart        # Windows 8 Metro UI tile dashboard
│   │   └── widgets/menu_tile.dart          # Flat rectangular sharp tile
│   │
│   ├── products/
│   │   ├── screens/products_screen.dart    # Product list, search, active filter
│   │   ├── screens/product_form_screen.dart# Product add/edit form
│   │   ├── widgets/product_list_item.dart
│   │   └── controllers/product_controller.dart
│   │
│   ├── customers/
│   │   ├── screens/customers_screen.dart   # Customer directory & quick search
│   │   ├── screens/customer_form_screen.dart# Customer add/edit form
│   │   ├── widgets/customer_list_item.dart
│   │   └── controllers/customer_controller.dart
│   │
│   └── settings/
│       ├── screens/settings_screen.dart    # Store branding, printers, database info
│       ├── widgets/settings_tile.dart
│       └── controllers/settings_controller.dart
│
└── shared/
    ├── widgets/
    │   ├── app_button.dart                 # Touch target action button (sharp corners)
    │   ├── app_text_field.dart             # Standardized text field
    │   ├── app_dialog.dart                 # Confirmation & alert modal helper
    │   ├── app_header.dart                 # Top navigation header
    │   ├── empty_state.dart                # Empty placeholder
    │   └── loading_indicator.dart          # Snappy POS spinner
    │
    └── layouts/responsive_layout.dart      # Landscape/portrait adaptive builder
```

---

## 🚀 Key Features

1. **Pure POS Numeric Keypad Login**
   - Masked PIN verification.
   - Large touch-friendly keypad with Backspace, Clear, and Enter.
   - Zero Android soft-keyboard popups.
   - Seeded PINs: Admin (`1234`), Cashier (`0000`).

2. **Main Billing Terminal (1280×720 Landscape)**
   - High-contrast billing table: `Description | Qty | Price | Total`.
   - In-line quantity adjustment (`+` / `-` / direct input keypad).
   - In-line unit price modification and automatic recalculation.
   - Barcode / Product Code quick scanner input.
   - Customer tab assignment (Walk-in vs Account clients).
   - Bill Discount calculation.
   - Multi-transaction **Hold Bill** & **Resume Bill** management.

3. **Windows 8 Metro Tile Menu**
   - Sharp flat rectangular tiles for Products, Customers, POS Billing, and Settings.

4. **Catalog & Customer Management**
   - Fast SQLite search indexing on barcode, code, description, and phone.
   - Product active/inactive toggle.
   - Modal add & edit workflows with field validation.

5. **Checkout & Thermal Printer Readiness**
   - Tender shortcuts (Exact, +500, +1000, +5000).
   - Immediate Change Due calculation.
   - Completed invoice receipt preview with test thermal print triggers.

---

## 🗄️ Local-First SQLite Schema

* `users` (`id`, `username`, `display_name`, `pin`, `role`, `active`, `created_at`)
* `products` (`id`, `code`, `barcode`, `description`, `price`, `cost`, `active`, `created_at`, `updated_at`)
* `customers` (`id`, `name`, `phone`, `email`, `address`, `created_at`, `updated_at`)
* `sales` (`id`, `invoice_no`, `customer_id`, `customer_name`, `subtotal`, `discount`, `tax`, `grand_total`, `paid_amount`, `change_amount`, `payment_method`, `status`, `cashier_name`, `created_at`, `updated_at`)
* `sale_items` (`id`, `sale_id`, `product_id`, `product_code`, `product_description`, `quantity`, `unit_price`, `unit_cost`, `line_total`)
* `settings` (`key`, `value`, `updated_at`)

---

## 🛠️ Testing & Verification

Run tests:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```
