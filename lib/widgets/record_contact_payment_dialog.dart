import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/number_to_words_service.dart';
import '../services/regional_data_service.dart';

/// Enterprise Add / Record Payment Modal
/// Supports real-time Amount in Words, Financial Overview Cards,
/// Date-Time Picker, Document Attachment, and Bilingual Labels.
class RecordContactPaymentDialog extends StatefulWidget {
  final Contact contact;
  final String contactType; // 'customer' or 'supplier'
  final BusinessSettings settings;
  final double? initialAmount;
  final double? totalDebit;
  final double? totalCredit;
  final double? openingBalance;
  final double? closingBalance;
  final VoidCallback? onPaymentRecorded;

  const RecordContactPaymentDialog({
    super.key,
    required this.contact,
    required this.contactType,
    required this.settings,
    this.initialAmount,
    this.totalDebit,
    this.totalCredit,
    this.openingBalance,
    this.closingBalance,
    this.onPaymentRecorded,
  });

  /// Static helper to display this dialog with clean backdrop and responsive constraints
  static Future<bool?> show(
    BuildContext context, {
    required Contact contact,
    required String contactType,
    required BusinessSettings settings,
    double? initialAmount,
    double? totalDebit,
    double? totalCredit,
    double? openingBalance,
    double? closingBalance,
    VoidCallback? onPaymentRecorded,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordContactPaymentDialog(
        contact: contact,
        contactType: contactType,
        settings: settings,
        initialAmount: initialAmount,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        openingBalance: openingBalance,
        closingBalance: closingBalance,
        onPaymentRecorded: onPaymentRecorded,
      ),
    );
  }

  @override
  State<RecordContactPaymentDialog> createState() =>
      _RecordContactPaymentDialogState();
}

class _RecordContactPaymentDialogState
    extends State<RecordContactPaymentDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  String? _attachedDocumentPath;
  bool _isSaving = false;
  String _nextRefNo = '';

  // Financial statistics
  double? _totalDebit;
  double? _totalCredit;
  double? _openingBalance;
  double? _closingBalance;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    final defaultAmt = widget.initialAmount ??
        (widget.contact.balance > 0 ? widget.contact.balance : 0.0);
    _amountCtrl = TextEditingController(
        text: defaultAmt > 0 ? defaultAmt.toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController();

    _totalDebit = widget.totalDebit;
    _totalCredit = widget.totalCredit;
    _openingBalance = widget.openingBalance;
    _closingBalance = widget.closingBalance ?? widget.contact.balance;

    _initRefAndStats();
  }

  Future<void> _initRefAndStats() async {
    final db = await DatabaseService.initialize();
    final ref = await db.generateNextPaymentRef();
    if (mounted) {
      setState(() => _nextRefNo = ref);
    }

    if (_totalDebit == null ||
        _totalCredit == null ||
        _openingBalance == null) {
      setState(() => _loadingStats = true);
      try {
        final res = await db.getContactLedger(
          contactId: widget.contact.id!,
          contactType: widget.contactType,
        );
        if (mounted) {
          setState(() {
            _totalDebit = (res['totalDebit'] as num?)?.toDouble() ?? 0.0;
            _totalCredit = (res['totalCredit'] as num?)?.toDouble() ?? 0.0;
            _openingBalance =
                (res['openingBalance'] as num?)?.toDouble() ?? 0.0;
            _closingBalance = (res['closingBalance'] as num?)?.toDouble() ??
                widget.contact.balance;
            _loadingStats = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingStats = false);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isCustomer => widget.contactType.toLowerCase() == 'customer';
  bool get _hasSecondary => widget.settings.hasEffectiveSecondaryLanguage;
  String get _secLang => widget.settings.secondaryLanguage;

  String _getTextForLang(String lang, {required bool isCustomer}) {
    switch (lang.toLowerCase()) {
      case 'ps':
        return isCustomer
            ? 'له پیرودونکي څخه پیسې ترلاسه کول'
            : 'عرضه کونکي ته پیسې ورکول';
      case 'fa':
        return isCustomer ? 'دریافت وجه از مشتری' : 'پرداخت به تامین‌کننده';
      case 'ar':
        return isCustomer ? 'استلام دفعة من العميل' : 'سداد دفعة للمورد';
      case 'es':
        return isCustomer ? 'Recibir pago de cliente' : 'Pagar a proveedor';
      case 'nl':
        return isCustomer
            ? 'Betaling ontvangen van klant'
            : 'Leverancier betalen';
      case 'ur':
        return isCustomer ? 'گاہک سے رقم وصول کریں' : 'سپلائر کو ادائیگی کریں';
      default:
        return isCustomer ? 'Add Payment' : 'Pay Supplier';
    }
  }

  String _getSecondaryText({
    required String ur,
    required String ps,
    required String fa,
    required String es,
    required String nl,
    required String en,
  }) {
    switch (_secLang) {
      case 'ps':
        return ps;
      case 'fa':
        return fa;
      case 'es':
        return es;
      case 'nl':
        return nl;
      case 'en':
        return en;
      case 'ur':
      default:
        return ur;
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _chooseDocument() async {
    final picked = await NativeFileHelper.pickPaymentDocument();
    if (picked != null && mounted) {
      setState(() {
        _attachedDocumentPath = picked;
      });
    }
  }

  void _setAmount(double val) {
    setState(() {
      _amountCtrl.text = val > 0 ? val.toStringAsFixed(2) : '';
    });
  }

  Future<void> _savePayment() async {
    final rawAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (rawAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please enter a valid payment amount greater than zero.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseService.initialize();
      final ref = _nextRefNo.isNotEmpty
          ? _nextRefNo
          : await db.generateNextPaymentRef();

      final payment = ContactPayment(
        contactId: widget.contact.id!,
        contactName: widget.contact.name,
        paymentType: _isCustomer ? 'receive' : 'pay',
        amount: rawAmt,
        paymentMethod: _paymentMethod,
        date: DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDate),
        refNo: ref,
        note: _noteCtrl.text.trim(),
        documentPath: _attachedDocumentPath,
      );

      await db.addContactPayment(payment);

      if (mounted) {
        Navigator.pop(context, true);
        widget.onPaymentRecorded?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_isCustomer ? "Received" : "Paid"} ${widget.settings.currencySymbol} ${rawAmt.toStringAsFixed(2)} for ${widget.contact.name} successfully!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final curCode = widget.settings.currencyCode;
    final wordsLang = widget.settings.totalInWordsLanguage;

    final parsedAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final amountWords = NumberToWordsService.convert(
      parsedAmount,
      language: wordsLang,
      currencySymbol: cur,
      currencyCode: curCode,
    );

    String? secondaryAmountWords;
    if (_hasSecondary && _secLang != wordsLang) {
      secondaryAmountWords = NumberToWordsService.convert(
        parsedAmount,
        language: _secLang,
        currencySymbol: cur,
        currencyCode: curCode,
      );
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final totalDebitVal =
        _totalDebit ?? (_isCustomer ? widget.contact.balance : 0.0);
    final totalCreditVal = _totalCredit ?? 0.0;
    final totalDueVal = _closingBalance ?? widget.contact.balance;
    final openingBalVal = _openingBalance ?? 0.0;
    final openingBalDueVal = openingBalVal > 0 ? openingBalVal : 0.0;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Bar
            _buildHeader(isDark, textPrimary, textSecondary),
            const Divider(height: 1, thickness: 1),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Row (Customer Info + Financial Summary Cards)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 580;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildCustomerCard(cardBg, borderColor,
                                    textPrimary, textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: _buildFinancialOverviewCard(
                                  cur: cur,
                                  totalDebit: totalDebitVal,
                                  totalCredit: totalCreditVal,
                                  totalDue: totalDueVal,
                                  openingBalance: openingBalVal,
                                  openingBalanceDue: openingBalDueVal,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildCustomerCard(cardBg, borderColor,
                                  textPrimary, textSecondary),
                              const SizedBox(height: 12),
                              _buildFinancialOverviewCard(
                                cur: cur,
                                totalDebit: totalDebitVal,
                                totalCredit: totalCreditVal,
                                totalDue: totalDueVal,
                                openingBalance: openingBalVal,
                                openingBalanceDue: openingBalDueVal,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // 3-Column Form Fields (Payment Method, Paid on, Amount)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isThreeCol = constraints.maxWidth > 650;
                        if (isThreeCol) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _buildPaymentMethodField(isDark,
                                      textPrimary, textSecondary, borderColor)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: _buildPaidOnField(isDark, textPrimary,
                                      textSecondary, borderColor)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: _buildAmountField(
                                      cur,
                                      totalDueVal,
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                      borderColor)),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPaymentMethodField(isDark, textPrimary,
                                  textSecondary, borderColor),
                              const SizedBox(height: 14),
                              _buildPaidOnField(isDark, textPrimary,
                                  textSecondary, borderColor),
                              const SizedBox(height: 14),
                              _buildAmountField(cur, totalDueVal, isDark,
                                  textPrimary, textSecondary, borderColor),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Live Amount in Words Showcase Banner
                    _buildAmountInWordsBanner(
                      parsedAmount: parsedAmount,
                      primaryWords: amountWords,
                      secondaryWords: secondaryAmountWords,
                      cur: cur,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                    const SizedBox(height: 20),

                    // Attach Document Section
                    _buildAttachDocumentSection(
                        isDark, textPrimary, textSecondary, borderColor),

                    const SizedBox(height: 20),

                    // Payment Note Multi-line Text Area
                    _buildPaymentNoteField(
                        isDark, textPrimary, textSecondary, borderColor),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // 3. Footer Action Buttons
            _buildFooter(isDark, textSecondary),
          ],
        ),
      ),
    );
  }

  /// 1. Top Header
  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary) {
    final primLang = widget.settings.activePrimaryLanguage;
    String primaryTitle = primLang == 'en'
        ? (_isCustomer ? 'Add Payment' : 'Pay Supplier')
        : _getTextForLang(primLang, isCustomer: _isCustomer);
    String? secondarySubtitle;

    if (_hasSecondary) {
      secondarySubtitle = _getSecondaryText(
        ur: _isCustomer ? 'گاہک سے رقم وصول کریں' : 'سپلائر کو ادائیگی کریں',
        ps: _isCustomer
            ? 'له پیرودونکي څخه پیسې ترلاسه کول'
            : 'عرضه کونکي ته پیسې ورکول',
        fa: _isCustomer ? 'دریافت وجه از مشتری' : 'پرداخت به تامین‌کننده',
        es: _isCustomer ? 'Recibir pago de cliente' : 'Pagar a proveedor',
        nl: _isCustomer
            ? 'Betaling ontvangen van klant'
            : 'Leverancier betalen',
        en: _isCustomer ? 'Receive Customer Payment' : 'Supplier Payment',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  if (secondarySubtitle != null)
                    Text(
                      secondarySubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
            tooltip: 'Close',
            hoverColor: isDark ? Colors.white10 : Colors.black12,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  /// Customer Info Card
  Widget _buildCustomerCard(
      Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final partyLabel = _isCustomer ? 'Customer name' : 'Supplier name';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$partyLabel: ',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textPrimary),
              ),
              Expanded(
                child: Text(
                  widget.contact.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (widget.contact.businessName != null &&
              widget.contact.businessName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Business: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: textSecondary),
                ),
                Expanded(
                  child: Text(
                    widget.contact.businessName!,
                    style: TextStyle(fontSize: 12, color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (widget.contact.phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Phone: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: textSecondary),
                ),
                Expanded(
                  child: Text(
                    widget.contact.phone,
                    style: TextStyle(fontSize: 12, color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Khata Code: ',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: textSecondary),
              ),
              Text(
                '#${_isCustomer ? "CUST" : "SUPP"}-${widget.contact.id}',
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7)),
              ),
            ],
          ),
          if (widget.contact.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: textSecondary),
                ),
                Expanded(
                  child: Text(
                    widget.contact.address,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Financial Overview Metrics Card
  Widget _buildFinancialOverviewCard({
    required String cur,
    required double totalDebit,
    required double totalCredit,
    required double totalDue,
    required double openingBalance,
    required double openingBalanceDue,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isDebitGreater = totalDebit > totalCredit;
    final saleDue = isDebitGreater ? (totalDebit - totalCredit) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: _loadingStats
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF059669)),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _financeRow(
                  label: _isCustomer ? 'Total Sale:' : 'Total Purchase:',
                  value: '$cur ${NumberFormat('#,##0.00').format(totalDebit)}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 4),
                _financeRow(
                  label: 'Total Paid:',
                  value: '$cur ${NumberFormat('#,##0.00').format(totalCredit)}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor: const Color(0xFF059669),
                ),
                const SizedBox(height: 4),
                _financeRow(
                  label:
                      _isCustomer ? 'Total Sale Due:' : 'Total Purchase Due:',
                  value:
                      '$cur ${NumberFormat('#,##0.00').format(saleDue > 0 ? saleDue : totalDue)}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  valueColor: (saleDue > 0 || totalDue > 0)
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                  isBold: true,
                ),
                const SizedBox(height: 4),
                _financeRow(
                  label: 'Opening Balance:',
                  value:
                      '$cur ${NumberFormat('#,##0.00').format(openingBalance)}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                const SizedBox(height: 4),
                _financeRow(
                  label: 'Opening Balance Due:',
                  value:
                      '$cur ${NumberFormat('#,##0.00').format(openingBalanceDue)}',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
    );
  }

  Widget _financeRow({
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? textPrimary,
          ),
        ),
      ],
    );
  }

  /// Field 1: Payment Method Dropdown
  Widget _buildPaymentMethodField(
      bool isDark, Color textPrimary, Color textSecondary, Color borderColor) {
    String label = 'Payment Method:*';
    if (_hasSecondary) {
      final sub = _getSecondaryText(
        ur: 'ادائیگی کا طریقہ',
        ps: 'د تادیې طریقه',
        fa: 'روش پرداخت',
        es: 'Método de pago',
        nl: 'Betaalmethode',
        en: 'Payment Method',
      );
      label = 'Payment Method ($sub):*';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMethod,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              items: [
                _buildMethodItem(
                    'cash',
                    Icons.money_rounded,
                    'Cash',
                    _getSecondaryText(
                        ur: 'نقد / کیش',
                        ps: 'نغدې',
                        fa: 'نقدی',
                        es: 'Efectivo',
                        nl: 'Contant',
                        en: 'Cash')),
                _buildMethodItem(
                    'bank_transfer',
                    Icons.account_balance_rounded,
                    'Bank',
                    _getSecondaryText(
                        ur: 'بینک',
                        ps: 'بانک',
                        fa: 'حساب بانکی',
                        es: 'Banco',
                        nl: 'Bank',
                        en: 'Bank')),
                _buildMethodItem(
                    'card',
                    Icons.credit_card_rounded,
                    'Card',
                    _getSecondaryText(
                        ur: 'کارڈ',
                        ps: 'کارت',
                        fa: 'کارت‌خوان',
                        es: 'Tarjeta',
                        nl: 'Kaart',
                        en: 'Card')),
                _buildMethodItem(
                    'cheque',
                    Icons.receipt_long_rounded,
                    'Cheque',
                    _getSecondaryText(
                        ur: 'چیک',
                        ps: 'چک',
                        fa: 'چک',
                        es: 'Cheque',
                        nl: 'Cheque',
                        en: 'Cheque')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<String> _buildMethodItem(
      String value, IconData icon, String title, String sub) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF059669)),
          const SizedBox(width: 8),
          Text(
            _hasSecondary ? '$title ($sub)' : title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Field 2: Paid On Interactive Date & Time Picker
  Widget _buildPaidOnField(
      bool isDark, Color textPrimary, Color textSecondary, Color borderColor) {
    String label = 'Paid on:*';
    if (_hasSecondary) {
      final sub = _getSecondaryText(
        ur: 'ادائیگی کی تاریخ',
        ps: 'د تادیې نېټه',
        fa: 'تاریخ پرداخت',
        es: 'Fecha de pago',
        nl: 'Betaaldatum',
        en: 'Payment Date',
      );
      label = 'Paid on ($sub):*';
    }

    final formatted = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  child: const Icon(Icons.calendar_month_outlined,
                      size: 18, color: Color(0xFF0284C7)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.edit_calendar_rounded,
                      size: 16, color: textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Field 3: Amount Field with Quick Fill Chips
  Widget _buildAmountField(String cur, double totalDue, bool isDark,
      Color textPrimary, Color textSecondary, Color borderColor) {
    String label = 'Amount:*';
    if (_hasSecondary) {
      final sub = _getSecondaryText(
        ur: 'رقم',
        ps: 'پیسې',
        fa: 'مبلغ',
        es: 'Monto',
        nl: 'Bedrag',
        en: 'Amount',
      );
      label = 'Amount ($sub):*';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: Center(
                  child: Text(
                    cur,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF059669)),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    hintText: '0.00',
                  ),
                  onChanged: (val) {
                    setState(() {}); // Triggers live Amount in Words update
                  },
                ),
              ),
            ],
          ),
        ),
        if (totalDue > 0) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildQuickChip(
                label: 'Full Due ($cur${totalDue.toStringAsFixed(0)})',
                onTap: () => _setAmount(totalDue),
                isDark: isDark,
              ),
              _buildQuickChip(
                label: '50%',
                onTap: () => _setAmount(totalDue / 2),
                isDark: isDark,
              ),
              _buildQuickChip(
                label: 'Clear',
                onTap: () => _setAmount(0.0),
                isDark: isDark,
                color: Colors.redAccent.withValues(alpha: 0.15),
                textColor: Colors.redAccent,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color ?? (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor ??
                (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  /// Live Amount In Words Banner
  Widget _buildAmountInWordsBanner({
    required double parsedAmount,
    required String primaryWords,
    required String? secondaryWords,
    required String cur,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final hasVal = parsedAmount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasVal
            ? (isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFFF0FDF4))
            : (isDark ? Colors.white10 : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasVal
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasVal
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.record_voice_over_outlined,
              size: 16,
              color: hasVal ? const Color(0xFF059669) : textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Amount in Words: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasVal ? const Color(0xFF059669) : textSecondary,
                      ),
                    ),
                    if (hasVal)
                      Text(
                        '($cur ${parsedAmount.toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasVal
                      ? primaryWords
                      : 'Enter payment amount above to view in words...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasVal ? FontWeight.bold : FontWeight.normal,
                    color: hasVal ? textPrimary : textSecondary,
                    fontStyle: hasVal ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (hasVal &&
                    secondaryWords != null &&
                    secondaryWords.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryWords,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasVal ? const Color(0xFF059669) : textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Attach Document
  Widget _buildAttachDocumentSection(
      bool isDark, Color textPrimary, Color textSecondary, Color borderColor) {
    String label = 'Attach Document:';
    if (_hasSecondary) {
      final sub = _getSecondaryText(
        ur: 'دستاویز یا رسید منسلک کریں',
        ps: 'سند ضمیمه کړئ',
        fa: 'پیوست سند یا رسید',
        es: 'Adjuntar documento',
        nl: 'Document bijvoegen',
        en: 'Attach Document',
      );
      label = 'Attach Document ($sub):';
    }

    final hasFile =
        _attachedDocumentPath != null && _attachedDocumentPath!.isNotEmpty;
    final filename =
        hasFile ? p.basename(_attachedDocumentPath!) : 'No file chosen';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _chooseDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF334155) : const Color(0xFF475569),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Choose File',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasFile
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              filename,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF065F46),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                setState(() => _attachedDocumentPath = null),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      'No file chosen',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Allowed File: .pdf, .csv, .zip, .doc, .docx, .jpeg, .jpg, .png',
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
      ],
    );
  }

  /// Payment Note
  Widget _buildPaymentNoteField(
      bool isDark, Color textPrimary, Color textSecondary, Color borderColor) {
    String label = 'Payment Note:';
    if (_hasSecondary) {
      final sub = _getSecondaryText(
        ur: 'تفصیل یا رسید نمبر',
        ps: 'یادښت یا رسید شمېره',
        fa: 'توضیحات و شماره سند',
        es: 'Nota o referencia',
        nl: 'Notitie / Referentie',
        en: 'Payment Note',
      );
      label = 'Payment Note ($sub):';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          minLines: 3,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            hintText:
                'Enter payment reference, bank slip number, cheque number, or transaction notes...',
            hintStyle: TextStyle(
                fontSize: 12, color: textSecondary.withValues(alpha: 0.7)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: Color(0xFF059669), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  /// 3. Footer
  Widget _buildFooter(bool isDark, Color textSecondary) {
    String cancelLabel = 'Cancel';
    String saveLabel = 'Save Payment & Update Khata';

    if (_hasSecondary) {
      final cancelSub = _getSecondaryText(
        ur: 'منسوخ',
        ps: 'لغوه',
        fa: 'انصراف',
        es: 'Cancelar',
        nl: 'Annuleren',
        en: 'Cancel',
      );
      cancelLabel = 'Cancel / $cancelSub';

      final saveSub = _getSecondaryText(
        ur: 'محفوظ کریں',
        ps: 'خوندي کړئ',
        fa: 'ثبت و بروزرسانی',
        es: 'Guardar pago',
        nl: 'Opslaan',
        en: 'Save',
      );
      saveLabel = 'Save Payment ($saveSub)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: textSecondary,
              side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(cancelLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 1,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(
              _isSaving ? 'Processing...' : saveLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
