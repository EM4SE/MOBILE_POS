/// Database schema table and column constants
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'pos_database.db';
  static const int databaseVersion = 1;

  // Table names
  static const String tableUsers = 'users';
  static const String tableProducts = 'products';
  static const String tableCustomers = 'customers';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableSettings = 'settings';
  static const String tableBusinessDays = 'business_days';
  static const String tableShifts = 'shifts';

  // Common Columns
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // Business Days Columns
  static const String colDayNumber = 'day_number';
  static const String colOpenedAt = 'opened_at';
  static const String colClosedAt = 'closed_at';
  static const String colOpenedBy = 'opened_by';
  static const String colClosedBy = 'closed_by';
  static const String colOpeningBalance = 'opening_balance';
  static const String colClosingBalance = 'closing_balance';
  static const String colExpectedBalance = 'expected_balance';

  // Shifts Columns
  static const String colDayId = 'day_id';
  static const String colShiftNumber = 'shift_number';
  static const String colCashierUsername = 'cashier_username';
  static const String colCashSales = 'cash_sales';
  static const String colTotalSales = 'total_sales';
  static const String colPaidIn = 'paid_in';
  static const String colPaidOut = 'paid_out';
  static const String colCashDifference = 'cash_difference';

  // Users Columns
  static const String colUsername = 'username';
  static const String colDisplayName = 'display_name';
  static const String colPin = 'pin';
  static const String colRole = 'role';
  static const String colActive = 'active';

  // Products Columns
  static const String colCode = 'code';
  static const String colBarcode = 'barcode';
  static const String colDescription = 'description';
  static const String colPrice = 'price';
  static const String colCost = 'cost';

  // Customers Columns
  static const String colName = 'name';
  static const String colPhone = 'phone';
  static const String colEmail = 'email';
  static const String colAddress = 'address';

  // Sales Columns
  static const String colInvoiceNo = 'invoice_no';
  static const String colCustomerId = 'customer_id';
  static const String colCustomerName = 'customer_name';
  static const String colSubtotal = 'subtotal';
  static const String colDiscount = 'discount';
  static const String colTax = 'tax';
  static const String colGrandTotal = 'grand_total';
  static const String colPaidAmount = 'paid_amount';
  static const String colChangeAmount = 'change_amount';
  static const String colPaymentMethod = 'payment_method';
  static const String colStatus = 'status'; // 'COMPLETED', 'HELD', 'CANCELLED'
  static const String colCashierName = 'cashier_name';

  // Sale Items Columns
  static const String colSaleId = 'sale_id';
  static const String colProductId = 'product_id';
  static const String colProductCode = 'product_code';
  static const String colProductDescription = 'product_description';
  static const String colQuantity = 'quantity';
  static const String colUnitPrice = 'unit_price';
  static const String colUnitCost = 'unit_cost';
  static const String colLineTotal = 'line_total';

  // Settings Columns
  static const String colKey = 'key';
  static const String colValue = 'value';
}
