import '../models/models.dart';
import '../services/database_service.dart';

/// Clean Domain Repository for Inventory, Products, and Serial Batches.
/// Reusable directly by Flutter Desktop and future companion Flutter Mobile App.
abstract class IInventoryRepository {
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search});
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByCode(String code);
  Future<int> addProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<List<Category>> getCategories();
  Future<List<Brand>> getBrands();
  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId);
  Future<ProductSerialBatch?> getProductSerialByImei(String imei);
  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId);
  Future<List<ProductBundleItem>> getBundleItems(int parentProductId);
}

class InventoryRepository implements IInventoryRepository {
  final DatabaseService _dbService;

  InventoryRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search}) {
    return _dbService.getProducts(categoryId: categoryId, brandId: brandId, search: search);
  }

  @override
  Future<Product?> getProductById(int id) => _dbService.getProductById(id);

  @override
  Future<Product?> getProductByCode(String code) => _dbService.getProductByCode(code);

  @override
  Future<int> addProduct(Product product) => _dbService.addProduct(product);

  @override
  Future<int> updateProduct(Product product) => _dbService.updateProduct(product);

  @override
  Future<int> deleteProduct(int id) => _dbService.deleteProduct(id);

  @override
  Future<List<Category>> getCategories() => _dbService.getCategories();

  @override
  Future<List<Brand>> getBrands() => _dbService.getBrands();

  @override
  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId) {
    return _dbService.getProductSerialsBatches(productId);
  }

  @override
  Future<ProductSerialBatch?> getProductSerialByImei(String imei) {
    return _dbService.getProductSerialByImei(imei);
  }

  @override
  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId) {
    return _dbService.getActiveBatchesForProduct(productId);
  }

  @override
  Future<List<ProductBundleItem>> getBundleItems(int parentProductId) {
    return _dbService.getBundleItems(parentProductId);
  }
}
