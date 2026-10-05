import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 5: Customer & Supplier Ledgers, Due Payment Receipts, and Balance Reconciliation', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase5_test_');
    final dbPath = '${tempDir.path}/test_phase5.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Create a customer with credit balance
    final customerId = await dbService.addContact(Contact(
      type: 'customer',
      name: 'Tariq Mehmood',
      businessName: 'Mehmood Electronics',
      phone: '+92 300 1234567',
      email: 'tariq@example.com',
      balance: 450.0, // Existing due balance
      creditLimit: 2000.0,
    ));
    expect(customerId, isNonZero);

    // Verify customer loaded with due balance
    var customer = await dbService.getContactById(customerId);
    expect(customer, isNotNull);
    expect(customer!.balance, equals(450.0));

    // 2. Receive partial payment from customer
    final payRef = await dbService.generateNextPaymentRef();
    expect(payRef.startsWith('PAY-'), isTrue);

    final payment = ContactPayment(
      contactId: customerId,
      contactName: customer.name,
      paymentType: 'receive',
      amount: 250.0,
      paymentMethod: 'cash',
      date: DateTime.now().toIso8601String(),
      refNo: payRef,
      note: 'Partial cash settlement for Invoice #102',
    );

    final paymentId = await dbService.addContactPayment(payment);
    expect(paymentId, isNonZero);

    // Verify customer balance decremented (450 - 250 = 200)
    customer = await dbService.getContactById(customerId);
    expect(customer!.balance, equals(200.0));

    // Verify contact payments ledger entries
    final customerPayments = await dbService.getContactPayments(customerId);
    expect(customerPayments.length, equals(1));
    expect(customerPayments.first.amount, equals(250.0));
    expect(customerPayments.first.paymentType, equals('receive'));

    // 3. Create a supplier with payable balance
    final supplierId = await dbService.addContact(Contact(
      type: 'supplier',
      name: 'Shenzhen Tech Components Ltd',
      businessName: 'Shenzhen Tech',
      phone: '+86 755 88889999',
      balance: 1500.0, // Payable due
    ));
    expect(supplierId, isNonZero);

    // Pay due to supplier
    final supplierPayRef = await dbService.generateNextPaymentRef();
    final supplierPayment = ContactPayment(
      contactId: supplierId,
      contactName: 'Shenzhen Tech Components Ltd',
      paymentType: 'pay',
      amount: 1000.0,
      paymentMethod: 'bank_transfer',
      date: DateTime.now().toIso8601String(),
      refNo: supplierPayRef,
      note: 'Wire transfer TT-98124',
    );

    final supPaymentId = await dbService.addContactPayment(supplierPayment);
    expect(supPaymentId, isNonZero);

    // Verify supplier balance decremented (1500 - 1000 = 500)
    final supplier = await dbService.getContactById(supplierId);
    expect(supplier!.balance, equals(500.0));

    final supplierPayments = await dbService.getContactPayments(supplierId);
    expect(supplierPayments.length, equals(1));
    expect(supplierPayments.first.amount, equals(1000.0));
    expect(supplierPayments.first.paymentType, equals('pay'));

    // Cleanup SQLite lock on Windows
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
