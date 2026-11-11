import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'core_providers.dart';

/// Immutable catalog state containing products, categories, and brands.
class CatalogState {
  final List<Product> products;
  final List<Category> categories;
  final List<Brand> brands;

  const CatalogState({
    this.products = const [],
    this.categories = const [],
    this.brands = const [],
  });

  List<Product> filter({
    int? categoryId,
    int? brandId,
    bool featuredOnly = false,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (brandId != null && p.brandId != brandId) return false;
      if (featuredOnly && ((p.id ?? 0) % 5 != 0)) return false;
      if (q.isNotEmpty) {
        final nameMatch = p.name.toLowerCase().contains(q);
        final skuMatch = p.sku.toLowerCase().contains(q);
        final barcodeMatch = p.barcode.toLowerCase().contains(q);
        final batchMatch =
            p.batchNumber != null && p.batchNumber!.toLowerCase().contains(q);
        if (!nameMatch && !skuMatch && !barcodeMatch && !batchMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

/// Reactive product/category/brand catalog provider backed by [ProductRepository].
class ProductListNotifier extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() async => _fetchCatalog();

  Future<CatalogState> _fetchCatalog() async {
    final repo = ref.read(productRepositoryProvider);
    final products = await repo.getProducts();
    final categories = await repo.getCategories();
    final brands = await repo.getBrands();
    return CatalogState(
      products: products,
      categories: categories,
      brands: brands,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchCatalog);
  }
}

final productListProvider =
    AsyncNotifierProvider<ProductListNotifier, CatalogState>(
  ProductListNotifier.new,
);

