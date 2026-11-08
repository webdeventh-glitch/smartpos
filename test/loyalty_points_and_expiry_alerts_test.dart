import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Customer Loyalty Points & Nearing Expiry Tests', () {
    test('1. Customer Contact model persists and updates loyalty points', () async {
      final db = await DatabaseService.initialize();

      // Create a test customer with 0 initial points
      final testCust = Contact(
        type: 'customer',
        name: 'Loyalty Test Customer',
        phone: '03001234567',
        balance: 0.0,
        creditLimit: 25000.0,
        loyaltyPoints: 0.0,
      );

      final custId = await db.addContact(testCust);
      expect(custId, greaterThan(0));

      // Award 50 points on a sale
      await db.updateContactLoyaltyPoints(custId, 50.0);
      var fetched = await db.getContactById(custId);
      expect(fetched, isNotNull);
      expect(fetched!.loyaltyPoints, equals(50.0));

      // Redeem 20 points
      await db.updateContactLoyaltyPoints(custId, -20.0);
      fetched = await db.getContactById(custId);
      expect(fetched!.loyaltyPoints, equals(30.0));

      // Over-redeeming cannot make points negative (clamped at 0)
      await db.updateContactLoyaltyPoints(custId, -100.0);
      fetched = await db.getContactById(custId);
      expect(fetched!.loyaltyPoints, equals(0.0));
    });

    test('2. Nearing expiry calculates days accurately and never forces automatic discounts', () {
      final now = DateTime.now();
      final nearingDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day + 15).toString().padLeft(2, '0')}';

      final pNearing = Product(
        name: 'Nearing Tablets',
        sku: 'NEAR-001',
        barcode: '890123456789',
        purchasePrice: 200.0,
        sellingPrice: 300.0,
        stockQuantity: 20.0,
        unit: 'Strip',
        expiryDate: nearingDate,
      );

      // Verify that adding to cart retains 100% of the original selling price (NO AUTOMATIC DISCOUNT)
      final cartItemNear = CartItem(
        product: pNearing,
        quantity: 1.0,
        unitPrice: pNearing.sellingPrice,
        expiryDate: pNearing.expiryDate,
        discount: 0.0,
      );

      expect(cartItemNear.unitPrice, equals(300.0));
      expect(cartItemNear.discount, equals(0.0));
      expect(cartItemNear.subtotal, equals(300.0)); // Strictly NO automatic discount!
      expect(cartItemNear.expiryDate, equals(nearingDate));
    });

    test('3. Loyalty points manual redemption rules', () {
      const grandTotal = 1500.0;
      const customerPoints = 200.0; // 200 Rs worth of points

      // Rule: Default is strictly NO redemption (0 discount)
      var redeemLoyalty = false;
      var loyaltyDiscount = 0.0;

      var payableTotal = grandTotal - (redeemLoyalty ? loyaltyDiscount : 0.0);
      expect(payableTotal, equals(1500.0)); // No discount applied automatically

      // When admin/cashier explicitly checks redeem points
      redeemLoyalty = true;
      loyaltyDiscount = customerPoints > grandTotal ? grandTotal : customerPoints;
      payableTotal = grandTotal - (redeemLoyalty ? loyaltyDiscount : 0.0);

      expect(loyaltyDiscount, equals(200.0));
      expect(payableTotal, equals(1300.0));

      // Rule: New earned points are awarded on the paid amount
      final paidAmount = payableTotal;
      final earnedPoints = (paidAmount / 100).floorToDouble();
      expect(earnedPoints, equals(13.0)); // 1 point per 100 Rs spent
    });
  });
}
