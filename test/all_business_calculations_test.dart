import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/providers/cart_provider.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/regional_data_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('All 26 Business Types & Precision Calculations Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_all_biz_');
      final dbPath = path.join(
          tempDir.path, 'test_biz_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test(
        'Every supported industry preset resolves valid modules & display name',
        () {
      expect(allSupportedIndustries.length, greaterThanOrEqualTo(26));
      for (final industry in allSupportedIndustries) {
        final settings = BusinessSettings(businessType: industry.key);
        expect(settings.businessTypeDisplayName.trim(), isNotEmpty,
            reason: 'Missing display name for ${industry.key}');
        final mods =
            BusinessSettings.defaultModulesForBusinessType(industry.key);
        expect(mods, isNotEmpty,
            reason: 'Missing default modules for ${industry.key}');
      }
      // Bakery under restaurant preset gets Manufacturing BOM + Batch Expiry
      final restBakery = BusinessSettings(businessType: 'restaurant');
      expect(restBakery.isRestaurantEnabled, isTrue);
      expect(restBakery.isModuleEnabled(BusinessSettings.moduleManufacturing),
          isTrue);
      expect(restBakery.isModuleEnabled(BusinessSettings.moduleBatchExpiry),
          isTrue);
    });

    test(
        'CartItem & CartState avoid floating-point drift on decimal weights, discounts & taxes',
        () {
      // e.g. Dairy / Bakery / Kiryana: 3 * 1.1 = 3.30 (not 3.3000000000000003)
      final item1 = CartItem(
        product: Product(
          name: 'Fresh Milk / Bakery',
          sku: 'MLK-1',
          barcode: 'MLK-1',
          unit: 'Liter',
          purchasePrice: 1.0,
          sellingPrice: 1.1,
          stockQuantity: 100.0,
        ),
        quantity: 3.0,
        unitPrice: 1.1,
      );
      expect(item1.packValue, 3.30);
      expect(item1.subtotal, 3.30);

      // 0.250 kg @ Rs 333/kg -> unitPrice = 0.333 per gram, 250g -> exact 83.25
      final gramItem = CartItem(
        product: Product(
          name: 'Almonds / Sweets',
          sku: 'SW-1',
          barcode: 'SW-1',
          unit: 'Kilogram',
          purchasePrice: 250.0,
          sellingPrice: 333.0,
          stockQuantity: 50.0,
        ),
        quantity: 250.0,
        unitPrice: 333.0,
      );
      gramItem.changeUnit('Gram (0.001Kg)', 0.001);
      expect(gramItem.subtotal, 83.25);

      // Percentage discount + TaxGroup calculation (exact sum preservation)
      gramItem.setItemDiscount(
          'percentage', 10.0); // 10% of 83.25 = 8.325 -> 8.32
      expect(gramItem.calculatedDiscount, 8.32);
      expect(gramItem.subtotal, 74.93);
      expect(
          gramItem.calculatedDiscount + gramItem.subtotal, gramItem.packValue);

      // Resuming SaleItem with unitMultiplier preserves base unit price
      final saleItem = SaleItem(
        saleId: 1,
        productId: 1,
        productName: 'Panadol',
        sku: 'PAN-1',
        unitPrice: 100.0, // Strip of 10
        quantity: 2.0,
        unitName: 'Strip (10 Tabs)',
        unitMultiplier: 10.0,
        subtotal: 200.0,
      );
      final resumed = CartItem.fromSaleItem(saleItem);
      expect(resumed.basePrice, 10.0);
      resumed.changeUnit('Tablet', 1.0);
      expect(resumed.unitPrice, 10.0);

      // CartState rounding & TaxGroup (additive vs compound)
      final gst = TaxRate(id: 1, name: 'GST', amount: 17.0);
      final sur = TaxRate(id: 2, name: 'Surcharge', amount: 1.0);
      const compoundTax = TaxGroup(
        id: 10,
        name: 'GST + Surcharge',
        subTaxIds: [1, 2],
        isCompound: true,
      );
      final cart = CartState(
        items: [item1],
        orderTax: compoundTax.calculateTotalTax(item1.subtotal, [gst, sur]),
      );
      expect(cart.grandTotal,
          double.parse((3.30 + cart.orderTax).toStringAsFixed(2)));
    });

    test(
        'Medicine Distribution: 10+1 bonus qty deducts stock, updates COGS, and restores on delete/update',
        () async {
      final prodId = await dbService.addProduct(Product(
        name: 'Panadol Syrup 120ml',
        sku: 'MED-PAN-120',
        barcode: 'MED-PAN-120',
        purchasePrice: 100.0,
        sellingPrice: 130.0,
        stockQuantity: 10.0,
      ));
      final prod = (await dbService.getProductById(prodId))!;

      // Purchase 20 + 2 bonus from supplier -> +22 in stock (total 32)
      await dbService.createPurchase(
        purchase: Purchase(
          refNo: 'PO-PHARMA-1',
          supplierName: 'GSK Pharma',
          totalAmount: 2000.0,
          paidAmount: 2000.0,
          status: 'received',
          paymentStatus: 'paid',
          createdAt: '2026-11-24T10:00:00',
        ),
        items: [
          {
            'product_id': prodId,
            'product_name': prod.name,
            'quantity': 20.0,
            'bonus_quantity': 2.0,
            'purchase_price': 100.0,
          }
        ],
      );
      expect((await dbService.getProductById(prodId))!.stockQuantity, 32.0);

      // Sell 10 + 1 bonus = 11 units out of stock, customer pays for 10 = Rs 1300
      final cartItem = CartItem(
        product: prod,
        quantity: 10.0,
        bonusQuantity: 1.0,
        unitPrice: 130.0,
      );
      expect(cartItem.subtotal, 1300.0);

      // Test overpayment dueAmount clamping (customer pays 1500 for 1300 bill -> dueAmount MUST be 0.0, not -200)
      final sale = Sale(
        invoiceNo: 'INV-MED-1',
        customerName: 'City Medical',
        subtotal: 1300.0,
        totalAmount: 1300.0,
        paidAmount: 1500.0,
        saleStatus: 'final',
        paymentStatus: 'paid',
        createdAt: '2026-11-25T11:00:00',
      );
      expect(sale.dueAmount, 0.0);

      final savedSale =
          await dbService.createSale(sale: sale, items: [cartItem]);
      expect(savedSale.items?.first.bonusQuantity, 1.0);
      expect((await dbService.getProductById(prodId))!.stockQuantity,
          21.0); // 32 - 11

      // P&L COGS must reflect 11 units * Rs 100 = 1100
      final pnl = await dbService.getProfitAndLossReport();
      expect(pnl['cogs'], 1100.0);
      expect(pnl['grossProfit'], 200.0); // 1300 - 1100

      // Deleting sale restores full 11 units (10 + 1 bonus) -> back to 32.0
      await dbService.deleteSale(savedSale.id!);
      expect((await dbService.getProductById(prodId))!.stockQuantity, 32.0);
    });
  });
}
