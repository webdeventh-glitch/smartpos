import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/number_to_words_service.dart';
import '../../../services/localization_service.dart';
import '../../../utils/currency_formatter.dart';

/// Clean modular widget representing the bottom cart summary breakdown
/// (items, subtotal, discount, tax, shipping, grand total payable)
/// and the primary checkout buttons (Cash, Card, Multi-pay, Credit, Park, Cancel).
class PosSummaryBar extends StatelessWidget {
  final BusinessSettings settings;
  final double totalQuantity;
  final double subtotal;
  final double calculatedDiscount;
  final double discountValue;
  final String discountType;
  final double orderTax;
  final double shippingCharge;
  final double grandTotal;
  final String wordsLanguage;
  final bool isSmallScreen;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onEditDiscount;
  final VoidCallback onEditTax;
  final VoidCallback onEditShipping;
  final VoidCallback onWordsLanguageTap;
  final VoidCallback onCancel;
  final VoidCallback onParkSale;
  final VoidCallback onDraftQuote;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onRecentTransactions;
  final VoidCallback? onSendToCashCounterToken;
  final VoidCallback onQuickCredit;
  final VoidCallback onQuickCard;
  final VoidCallback onMultiplePay;
  final VoidCallback onQuickCash;

  const PosSummaryBar({
    super.key,
    required this.settings,
    required this.totalQuantity,
    required this.subtotal,
    required this.calculatedDiscount,
    required this.discountValue,
    required this.discountType,
    required this.orderTax,
    required this.shippingCharge,
    required this.grandTotal,
    required this.wordsLanguage,
    required this.isSmallScreen,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onEditDiscount,
    required this.onEditTax,
    required this.onEditShipping,
    required this.onWordsLanguageTap,
    required this.onCancel,
    required this.onParkSale,
    required this.onDraftQuote,
    this.onSaveDraft,
    this.onRecentTransactions,
    this.onSendToCashCounterToken,
    required this.onQuickCredit,
    required this.onQuickCard,
    required this.onMultiplePay,
    required this.onQuickCash,
  });

  Widget _summaryBlock(
    String label,
    String value, {
    bool isEditable = false,
    VoidCallback? onEdit,
    required bool isDark,
    required bool isSmall,
  }) {
    return InkWell(
      onTap: isEditable ? onEdit : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 9.5 : 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                if (isEditable) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.edit_outlined,
                    size: isSmall ? 9 : 11,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmall ? 11 : 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = settings.currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFBBF7D0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Summary breakdown and Total Payable
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 16,
              vertical: isSmallScreen ? 6 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _summaryBlock(
                          PosLocalization.tr('ITEMS', settings: settings),
                          totalQuantity.toStringAsFixed(2),
                          isDark: isDark,
                          isSmall: isSmallScreen,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 14),
                        _summaryBlock(
                          PosLocalization.tr('SUBTOTAL', settings: settings),
                          CurrencyFormatter.exact(subtotal,
                              currency: '$currency '),
                          isDark: isDark,
                          isSmall: isSmallScreen,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 14),
                        _summaryBlock(
                          PosLocalization.tr('DISCOUNT(-)', settings: settings),
                          discountValue <= 0
                              ? '$currency 0.00'
                              : (discountType == 'percentage'
                                  ? '${discountValue.toStringAsFixed(discountValue.truncateToDouble() == discountValue ? 0 : 2)}% (${CurrencyFormatter.exact(calculatedDiscount, currency: '$currency ')})'
                                  : CurrencyFormatter.exact(calculatedDiscount,
                                      currency: '$currency ')),
                          isEditable: true,
                          onEdit: onEditDiscount,
                          isDark: isDark,
                          isSmall: isSmallScreen,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 14),
                        _summaryBlock(
                          PosLocalization.tr('ORDER TAX(+)',
                              settings: settings),
                          CurrencyFormatter.exact(orderTax,
                              currency: '$currency '),
                          isEditable: true,
                          onEdit: onEditTax,
                          isDark: isDark,
                          isSmall: isSmallScreen,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 14),
                        _summaryBlock(
                          PosLocalization.tr('SHIPPING(+)', settings: settings),
                          CurrencyFormatter.exact(shippingCharge,
                              currency: '$currency '),
                          isEditable: true,
                          onEdit: onEditShipping,
                          isDark: isDark,
                          isSmall: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 16),

                // Big Green TOTAL PAYABLE Box with Words
                InkWell(
                  onTap: onWordsLanguageTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Tooltip(
                    message: PosLocalization.trParams(
                      'Click to change words language ({lang})',
                      {'lang': wordsLanguage.toUpperCase()},
                      settings: settings,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 16,
                        vertical: isSmallScreen ? 4 : 6,
                      ),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 130 : 160,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF059669)
                              : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate,
                                size: isSmallScreen ? 10 : 11,
                                color: isDark
                                    ? const Color(0xFF6EE7B7)
                                        .withValues(alpha: 0.8)
                                    : const Color(0xFF16A34A)
                                        .withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                PosLocalization.tr('TOTAL PAYABLE',
                                    settings: settings),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF16A34A),
                                  letterSpacing: isSmallScreen ? 0.4 : 0.8,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.exact(grandTotal),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 26,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF15803D),
                              height: 1.1,
                            ),
                          ),
                          if (grandTotal > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isSmallScreen ? 180 : 240,
                                ),
                                child: Text(
                                  NumberToWordsService.convert(
                                    grandTotal,
                                    language: wordsLanguage,
                                    currencySymbol: settings.currencySymbol,
                                    currencyCode: settings.currencyCode,
                                  ),
                                  textDirection:
                                      NumberToWordsService.isRtl(wordsLanguage)
                                          ? ui.TextDirection.rtl
                                          : ui.TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 9.5 : 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: isDark
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFF166534),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Bottom Actions Row (Checkout & secondary action buttons)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: isSmallScreen ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Secondary Quick Action Tools
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: Text(
                          PosLocalization.tr('Cancel', settings: settings),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onCancel,
                      ),
                      if (onSaveDraft != null) ...[
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            foregroundColor: textPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.edit_note, size: 14),
                          label: Text(
                            PosLocalization.tr('Draft', settings: settings),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onSaveDraft,
                        ),
                      ],
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          foregroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon:
                            const Icon(Icons.request_quote_outlined, size: 14),
                        label: Text(
                          PosLocalization.tr('Quotation', settings: settings),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onDraftQuote,
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          foregroundColor: const Color(0xFFF59E0B),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.pause_circle_outline, size: 14),
                        label: Text(
                          PosLocalization.tr('Park [F4]', settings: settings),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onParkSale,
                      ),
                      if (settings.enableCounterTokenQueue &&
                          onSendToCashCounterToken != null) ...[
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0D9488)),
                            foregroundColor: const Color(0xFF0D9488),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.confirmation_number_outlined,
                              size: 14),
                          label: Text(
                            PosLocalization.tr('Send Token',
                                settings: settings),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onSendToCashCounterToken,
                        ),
                      ],
                      if (settings.enableCreditSale) ...[
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF8B5CF6)),
                            foregroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 14),
                          label: Text(
                            PosLocalization.tr('Credit / Khata [F6]',
                                settings: settings),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onQuickCredit,
                        ),
                      ],
                      if (onRecentTransactions != null) ...[
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF4338CA)
                                  : const Color(0xFFC7D2FE),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF312E81).withValues(alpha: 0.3)
                                : const Color(0xFFEEF2FF),
                            foregroundColor: isDark
                                ? const Color(0xFFA5B4FC)
                                : const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.access_time_rounded, size: 14),
                          label: Text(
                            PosLocalization.tr('Recent Sales [F9]',
                                settings: settings),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onRecentTransactions,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Primary Checkout Buttons (Card, Multiple Pay [F7], Cash [F2])
                Row(
                  children: [
                    if (settings.enableCardPayment) ...[
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.credit_card, size: 18),
                          label: Text(
                            PosLocalization.tr('Card [F8]', settings: settings),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                          onPressed: onQuickCard,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: settings.enableCardPayment ? 3 : 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: Text(
                          PosLocalization.tr('Multiple Pay [F7]',
                              settings: settings),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        onPressed: onMultiplePay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: settings.enableCardPayment ? 4 : 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 20),
                        label: Text(
                          '${PosLocalization.tr('Cash [F2]', settings: settings)} • $currency ${grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                        onPressed: onQuickCash,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
