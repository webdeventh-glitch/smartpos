import '../models/models.dart';
import '../services/database_service.dart';

/// Clean Domain Repository for Purchases & Supplier Orders.
/// Reusable directly by Flutter Desktop and future companion Flutter Mobile App.
abstract class IPurchaseRepository {
  Future<int> createPurchase({required Purchase purchase, required List<Map<String, dynamic>> items});
  Future<List<Purchase>> getPurchases();
  Future<void> settlePurchasePayment({required int purchaseId, required double amountPaid, required String paymentMethod, String accountName, String refNo, String note, String createdBy});
}

class PurchaseRepository implements IPurchaseRepository {
  final DatabaseService _dbService;

  PurchaseRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<int> createPurchase({
    required Purchase purchase,
    required List<Map<String, dynamic>> items,
  }) {
    return _dbService.createPurchase(purchase: purchase, items: items);
  }

  @override
  Future<List<Purchase>> getPurchases() {
    return _dbService.getPurchases();
  }

  @override
  Future<void> settlePurchasePayment({
    required int purchaseId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) {
    return _dbService.settlePurchasePayment(
      purchaseId: purchaseId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      accountName: accountName,
      refNo: refNo,
      note: note,
      createdBy: createdBy,
    );
  }
}
