/// Decimal-safe money helpers. Storage and all arithmetic use integer paisa.
class Money {
  static const maxUnitPrice = 9999999999;
  static const maxTotal = 9000000000000000;

  static int parse(String value) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('Enter a price with up to 2 decimal places.');
    }
    final parts = value.split('.');
    return int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  }

  static String decimal(int value) {
    final absolute = value.abs();
    return '${value < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  static String format(int value) => 'Rs ${decimal(value)}';

  static int lineTotal(int price, int quantity) {
    if (price < 0 ||
        price > maxUnitPrice ||
        quantity < 1 ||
        quantity > 100000000 ||
        (price != 0 && quantity > maxTotal ~/ price)) {
      throw ArgumentError('Price or quantity exceeds the supported limit.');
    }
    return price * quantity;
  }

  static int add(int total, int amount) {
    if (total < 0 ||
        amount < 0 ||
        amount > maxTotal ||
        total > maxTotal - amount) {
      throw ArgumentError('Document total exceeds the supported limit.');
    }
    return total + amount;
  }
}
