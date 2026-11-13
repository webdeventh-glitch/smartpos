import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/customer_group.dart';
import '../models/product.dart';
import '../models/product_variation.dart';
import '../models/tax_group.dart';
import '../models/tax_rate.dart';

/// Immutable snapshot of POS cart state (items, pricing tiers, tax groups, & discounts).
class CartState {
  final List<CartItem> items;
  final String discountType; // 'fixed' or 'percentage'
  final double discountValue;
  final double orderTax;
  final double shippingCharge;
  final bool isWholesaleMode;
  final double wholesaleDiscountPercent;
  final CustomerGroup? activeCustomerGroup;
  final TaxGroup? selectedTaxGroup;
  final TaxRate? selectedTaxRate;
  final Map<String, double> taxBreakdown;
  final int undoDepth;
  final int redoDepth;

  const CartState({
    this.items = const [],
    this.discountType = 'fixed',
    this.discountValue = 0.0,
    this.orderTax = 0.0,
    this.shippingCharge = 0.0,
    this.isWholesaleMode = false,
    this.wholesaleDiscountPercent = 10.0,
    this.activeCustomerGroup,
    this.selectedTaxGroup,
    this.selectedTaxRate,
    this.taxBreakdown = const {},
    this.undoDepth = 0,
    this.redoDepth = 0,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get canUndo => undoDepth > 0;
  bool get canRedo => redoDepth > 0;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);
  double get totalItemDiscounts =>
      items.fold(0.0, (sum, item) => sum + item.calculatedDiscount);
  double get totalQuantity =>
      items.fold(0.0, (sum, item) => sum + item.quantity);
  double get salesSubtotal => items
      .where((item) => item.quantity > 0)
      .fold(0.0, (sum, item) => sum + item.subtotal);
  double get returnsSubtotal => items
      .where((item) => item.quantity < 0)
      .fold(0.0, (sum, item) => sum + item.subtotal.abs());
  bool get hasReturns => items.any((item) => item.isReturnItem);

  double get calculatedDiscount {
    final base = salesSubtotal > 0 ? salesSubtotal : subtotal;
    if (base <= 0) return 0.0;
    final raw = discountType == 'percentage'
        ? base * (discountValue / 100.0)
        : discountValue;
    return raw.clamp(0.0, base);
  }

  double get taxableSubtotal =>
      (salesSubtotal - calculatedDiscount).clamp(0.0, double.infinity);

  double get grandTotal {
    final net = subtotal - calculatedDiscount + orderTax + shippingCharge;
    return net;
  }

  CartState _withHistory(int undoLen, int redoLen) => CartState(
        items: List<CartItem>.unmodifiable(items.map((e) => e.clone())),
        discountType: discountType,
        discountValue: discountValue,
        orderTax: orderTax,
        shippingCharge: shippingCharge,
        isWholesaleMode: isWholesaleMode,
        wholesaleDiscountPercent: wholesaleDiscountPercent,
        activeCustomerGroup: activeCustomerGroup,
        selectedTaxGroup: selectedTaxGroup,
        selectedTaxRate: selectedTaxRate,
        taxBreakdown: Map<String, double>.unmodifiable(taxBreakdown),
        undoDepth: undoLen,
        redoDepth: redoLen,
      );

  CartState copyWith({
    List<CartItem>? items,
    String? discountType,
    double? discountValue,
    double? orderTax,
    double? shippingCharge,
    bool? isWholesaleMode,
    double? wholesaleDiscountPercent,
    CustomerGroup? activeCustomerGroup,
    bool clearCustomerGroup = false,
    TaxGroup? selectedTaxGroup,
    bool clearTaxGroup = false,
    TaxRate? selectedTaxRate,
    bool clearTaxRate = false,
    Map<String, double>? taxBreakdown,
    int? undoDepth,
    int? redoDepth,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      orderTax: orderTax ?? this.orderTax,
      shippingCharge: shippingCharge ?? this.shippingCharge,
      isWholesaleMode: isWholesaleMode ?? this.isWholesaleMode,
      wholesaleDiscountPercent:
          wholesaleDiscountPercent ?? this.wholesaleDiscountPercent,
      activeCustomerGroup: clearCustomerGroup
          ? null
          : (activeCustomerGroup ?? this.activeCustomerGroup),
      selectedTaxGroup:
          clearTaxGroup ? null : (selectedTaxGroup ?? this.selectedTaxGroup),
      selectedTaxRate:
          clearTaxRate ? null : (selectedTaxRate ?? this.selectedTaxRate),
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      undoDepth: undoDepth ?? this.undoDepth,
      redoDepth: redoDepth ?? this.redoDepth,
    );
  }
}

/// Manages POS cart items, tiered customer pricing, group taxes, discounts, and multi-step Undo/Redo.
class CartNotifier extends Notifier<CartState> {
  static const int _maxHistory = 50;
  final List<CartState> _undoStack = [];
  final List<CartState> _redoStack = [];
  List<TaxRate> _cachedTaxRates = const [];

  @override
  CartState build() {
    _undoStack.clear();
    _redoStack.clear();
    _cachedTaxRates = const [];
    return const CartState();
  }

  CartState _recomputeAutoTax(CartState candidate) {
    final taxable = candidate.taxableSubtotal;
    if (candidate.selectedTaxGroup != null && _cachedTaxRates.isNotEmpty) {
      final breakdown = candidate.selectedTaxGroup!
          .calculateBreakdown(taxable, _cachedTaxRates);
      final total = candidate.selectedTaxGroup!
          .calculateTotalTax(taxable, _cachedTaxRates);
      return candidate.copyWith(
        orderTax: total,
        taxBreakdown: Map<String, double>.unmodifiable(breakdown),
      );
    }
    if (candidate.selectedTaxRate != null) {
      final r = candidate.selectedTaxRate!;
      final amt =
          double.parse((taxable * (r.amount / 100.0)).toStringAsFixed(2));
      return candidate.copyWith(
        orderTax: amt,
        taxBreakdown: Map<String, double>.unmodifiable({
          '${r.name} (${r.amount}%)': amt,
        }),
      );
    }
    return candidate;
  }

  void _commit(
    CartState nextState, {
    bool recordUndo = true,
    bool recomputeTax = true,
  }) {
    if (recordUndo) {
      _undoStack.add(state._withHistory(0, 0));
      if (_undoStack.length > _maxHistory) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
    }
    final prepared = recomputeTax ? _recomputeAutoTax(nextState) : nextState;
    state = prepared.copyWith(
      items: List<CartItem>.unmodifiable(prepared.items.map((e) => e.clone())),
      taxBreakdown: Map<String, double>.unmodifiable(prepared.taxBreakdown),
      undoDepth: _undoStack.length,
      redoDepth: _redoStack.length,
    );
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    final previous = _undoStack.removeLast();
    _redoStack.add(state._withHistory(0, 0));
    state = previous.copyWith(
      undoDepth: _undoStack.length,
      redoDepth: _redoStack.length,
    );
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    final restored = _redoStack.removeLast();
    _undoStack.add(state._withHistory(0, 0));
    state = restored.copyWith(
      undoDepth: _undoStack.length,
      redoDepth: _redoStack.length,
    );
    return true;
  }

  void addProduct(
    Product product, {
    double quantity = 1.0,
    bool mergeByUnitPrice = false,
    ProductVariation? variation,
    String? batchNumber,
    String? expiryDate,
  }) {
    final basePrice = variation?.sellingPrice ?? product.sellingPrice;
    final tieredPrice =
        state.activeCustomerGroup?.applyPricing(basePrice) ?? basePrice;
    final targetBatch = batchNumber ?? product.batchNumber;
    final targetExpiry = expiryDate ?? product.expiryDate;
    final updated = state.items.map((e) => e.clone()).toList();
    final idx = updated.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.variationId == variation?.id &&
          item.batchNumber == targetBatch &&
          (!mergeByUnitPrice || item.unitPrice == tieredPrice),
    );
    if (idx >= 0) {
      updated[idx].quantity += quantity;
    } else {
      final lineProduct =
          (variation != null && variation.subSku.trim().isNotEmpty)
              ? product.copyWith(sku: variation.subSku.trim())
              : product;
      updated.add(
        CartItem(
          product: lineProduct,
          variationId: variation?.id,
          variationName: variation?.name,
          basePrice: basePrice,
          quantity: quantity,
          unitPrice: tieredPrice,
          batchNumber: targetBatch,
          expiryDate: targetExpiry,
          packDiscount:
              state.isWholesaleMode ? state.wholesaleDiscountPercent : 0.0,
        ),
      );
    }
    _commit(state.copyWith(items: updated));
  }

  void addCustomItem(CartItem item) {
    final updated = [...state.items.map((e) => e.clone()), item.clone()];
    _commit(state.copyWith(items: updated));
  }

  void addBundleItems(List<CartItem> bundleItems) {
    if (bundleItems.isEmpty) return;
    final updated = [
      ...state.items.map((e) => e.clone()),
      ...bundleItems.map((e) => e.clone()),
    ];
    _commit(state.copyWith(items: updated));
  }

  void incrementQuantity(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    final cur = updated[index].quantity;
    updated[index].quantity = (cur < 1 && cur >= 0.25) ? cur + 0.25 : cur + 1.0;
    _commit(state.copyWith(items: updated));
  }

  void decrementQuantity(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    final cur = updated[index].quantity;
    if (cur > 1) {
      updated[index].quantity = cur - 1.0;
    } else if (cur > 0.25) {
      updated[index].quantity = cur - 0.25;
    } else {
      updated.removeAt(index);
    }
    _commit(state.copyWith(items: updated));
  }

  void setQuantity(int index, double quantity, {bool allowNegative = true}) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    if (quantity == 0 || (quantity < 0 && !allowNegative)) {
      updated.removeAt(index);
    } else {
      updated[index].quantity = quantity;
    }
    _commit(state.copyWith(items: updated));
  }

  void toggleItemAsReturn(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    final item = updated[index];
    if (item.quantity > 0) {
      item.quantity = -item.quantity.abs();
    } else {
      item.quantity = item.quantity.abs();
    }
    _commit(state.copyWith(items: updated));
  }

  void updateLineItem(
    int index, {
    required double unitPrice,
    double discount = 0.0,
    double packDiscount = 0.0,
    String? discountType,
    double? discountValue,
  }) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    updated[index].unitPrice = unitPrice < 0 ? 0.0 : unitPrice;
    if (discountType != null && discountValue != null) {
      updated[index].setItemDiscount(discountType, discountValue);
    } else if (packDiscount > 0 && discount == 0) {
      updated[index].setItemDiscount('percentage', packDiscount);
    } else if (discount > 0 && packDiscount == 0) {
      updated[index].setItemDiscount('fixed', discount);
    } else {
      updated[index].discount = discount < 0 ? 0.0 : discount;
      updated[index].packDiscount = packDiscount < 0 ? 0.0 : packDiscount;
      updated[index].discountType = packDiscount > 0 ? 'percentage' : 'fixed';
      updated[index].discountValue = packDiscount > 0
          ? updated[index].packDiscount
          : updated[index].discount;
    }
    _commit(state.copyWith(items: updated));
  }

  void setItemDiscount(int index, String type, double value) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    updated[index].setItemDiscount(type, value);
    _commit(state.copyWith(items: updated));
  }

  void changeItemUnit(int index, String unitName, double multiplier) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList();
    updated[index].changeUnit(unitName, multiplier);
    if (state.activeCustomerGroup != null) {
      updated[index].unitPrice =
          state.activeCustomerGroup!.applyPricing(updated[index].unitPrice);
    }
    _commit(state.copyWith(items: updated));
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = state.items.map((e) => e.clone()).toList()..removeAt(index);
    _commit(state.copyWith(items: updated));
  }

  /// Applies a [CustomerGroup] pricing tier to all current and future cart items.
  /// Pass `null` to revert items back to their base selling prices.
  void applyCustomerGroup(CustomerGroup? group) {
    final updated = state.items.map((e) => e.clone()).toList();
    for (final item in updated) {
      final mult = item.unitMultiplier > 0 ? item.unitMultiplier : 1.0;
      final baseUnit = item.basePrice * mult;
      item.unitPrice = group != null ? group.applyPricing(baseUnit) : baseUnit;
    }
    _commit(
      state.copyWith(
        items: updated,
        activeCustomerGroup: group,
        clearCustomerGroup: group == null,
      ),
    );
  }

  void toggleWholesaleMode() {
    final nextWholesale = !state.isWholesaleMode;
    final pct = state.wholesaleDiscountPercent;
    final updated = state.items.map((e) => e.clone()).toList();
    for (final item in updated) {
      if (nextWholesale) {
        if (item.packDiscount == 0.0 && item.discount == 0.0) {
          item.setItemDiscount('percentage', pct);
        }
      } else {
        if (item.discountType == 'percentage' && item.discountValue == pct) {
          item.setItemDiscount('fixed', 0.0);
        }
      }
    }
    _commit(state.copyWith(items: updated, isWholesaleMode: nextWholesale));
  }

  void setOrderDiscount(String type, double value) {
    _commit(
      state.copyWith(
        discountType: type,
        discountValue: value < 0 ? 0.0 : value,
      ),
    );
  }

  void setOrderTax(double tax) {
    final cleanTax = tax < 0.0 ? 0.0 : tax;
    _commit(
      state.copyWith(
        orderTax: cleanTax,
        clearTaxGroup: true,
        clearTaxRate: true,
        taxBreakdown: const {},
      ),
      recomputeTax: false,
    );
  }

  void applyTaxGroup(TaxGroup? group, List<TaxRate> availableRates) {
    _cachedTaxRates = List<TaxRate>.unmodifiable(availableRates);
    if (group == null) {
      _commit(
        state.copyWith(
          orderTax: 0.0,
          clearTaxGroup: true,
          clearTaxRate: true,
          taxBreakdown: const {},
        ),
        recomputeTax: false,
      );
      return;
    }
    final next = state.copyWith(
      selectedTaxGroup: group,
      clearTaxRate: true,
    );
    _commit(next, recomputeTax: true);
  }

  void applyTaxRate(TaxRate? rate) {
    if (rate == null) {
      _commit(
        state.copyWith(
          orderTax: 0.0,
          clearTaxGroup: true,
          clearTaxRate: true,
          taxBreakdown: const {},
        ),
        recomputeTax: false,
      );
      return;
    }
    final next = state.copyWith(
      selectedTaxRate: rate,
      clearTaxGroup: true,
    );
    _commit(next, recomputeTax: true);
  }

  void setShippingCharge(double shipping) {
    _commit(state.copyWith(shippingCharge: shipping < 0.0 ? 0.0 : shipping));
  }

  void loadFromSaved({
    required List<CartItem> items,
    String discountType = 'fixed',
    double discountValue = 0.0,
    double orderTax = 0.0,
    double shippingCharge = 0.0,
    bool? isWholesaleMode,
    CustomerGroup? activeCustomerGroup,
    TaxGroup? selectedTaxGroup,
    Map<String, double> taxBreakdown = const {},
  }) {
    _commit(
      CartState(
        items: items.map((e) => e.clone()).toList(),
        discountType: discountType,
        discountValue: discountValue,
        orderTax: orderTax,
        shippingCharge: shippingCharge,
        isWholesaleMode: isWholesaleMode ?? state.isWholesaleMode,
        wholesaleDiscountPercent: state.wholesaleDiscountPercent,
        activeCustomerGroup: activeCustomerGroup,
        selectedTaxGroup: selectedTaxGroup,
        taxBreakdown: Map<String, double>.unmodifiable(taxBreakdown),
      ),
      recomputeTax: selectedTaxGroup != null,
    );
  }

  void clear({bool resetHistory = false}) {
    final fresh = CartState(
      isWholesaleMode: state.isWholesaleMode,
      wholesaleDiscountPercent: state.wholesaleDiscountPercent,
    );
    if (resetHistory) {
      _undoStack.clear();
      _redoStack.clear();
      state = fresh;
      return;
    }
    _commit(fresh, recomputeTax: false);
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
