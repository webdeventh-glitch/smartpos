import '../models/models.dart';
import '../services/database_service.dart';

/// Clean Domain Repository for Sales & POS Transactions.
/// Reusable directly by Flutter Desktop and future companion Flutter Mobile App.
abstract class ISalesRepository {
  Future<Sale> createSale({required Sale sale, required List<CartItem> items, List<Map<String, dynamic>>? splitTenders});
  Future<List<Sale>> getSales({String? status, String? search});
  Future<List<SaleItem>> getSaleItems(int saleId);
  Future<void> settleSalePayment({required int saleId, required double amountPaid, required String paymentMethod, String accountName, String refNo, String note, String createdBy});
  Future<int> parkSale(ParkedSale parked);
  Future<List<ParkedSale>> getParkedSales();
  Future<int> deleteParkedSale(int id);
}

class SalesRepository implements ISalesRepository {
  final DatabaseService _dbService;

  SalesRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<Sale> createSale({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
  }) {
    return _dbService.createSale(
      sale: sale,
      items: items,
      splitTenders: splitTenders,
    );
  }

  @override
  Future<List<Sale>> getSales({String? status, String? search}) {
    return _dbService.getSales(status: status, search: search);
  }

  @override
  Future<List<SaleItem>> getSaleItems(int saleId) {
    return _dbService.getSaleItems(saleId);
  }

  @override
  Future<void> settleSalePayment({
    required int saleId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) {
    return _dbService.settleSalePayment(
      saleId: saleId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      accountName: accountName,
      refNo: refNo,
      note: note,
      createdBy: createdBy,
    );
  }

  @override
  Future<int> parkSale(ParkedSale parked) => _dbService.parkSale(parked);

  @override
  Future<List<ParkedSale>> getParkedSales() => _dbService.getParkedSales();

  @override
  Future<int> deleteParkedSale(int id) => _dbService.deleteParkedSale(id);
}
