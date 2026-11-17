import 'package:intl/intl.dart';

// Formatters are built once. The original `formatCurrency` cost ~3ms per call
// because it parsed locale data every time (a new NumberFormat per call).
// Reusing one instance makes each call microseconds, and with lazy lists
// only the rows on screen get formatted anyway.

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final NumberFormat _inrWhole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final DateFormat _date = DateFormat('d MMM yyyy');

final NumberFormat _count = NumberFormat.decimalPattern('en_IN');

/// ₹1,23,456.00 (Indian digit grouping).
String formatCurrency(int amountInPaise) => _inr.format(amountInPaise / 100);

/// ₹1,234, for whole-rupee amounts.
String formatRupees(int rupees) => _inrWhole.format(rupees);

String formatDate(DateTime date) => _date.format(date);

/// 3,000 (Indian digit grouping).
String formatCount(int n) => _count.format(n);
