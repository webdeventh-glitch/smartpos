import '../models/models.dart';
import '../services/database_service.dart';

/// Clean Domain Repository for Contacts (Customers, Suppliers, Ledger Balances).
/// Reusable directly by Flutter Desktop and future companion Flutter Mobile App.
abstract class IContactsRepository {
  Future<List<Contact>> getContacts({String? type, String? search});
  Future<Contact?> getContactById(int id);
  Future<int> addContact(Contact contact);
  Future<int> updateContact(Contact contact);
  Future<int> deleteContact(int id);
  Future<void> updateContactBalance(int contactId, double delta);
  Future<bool> isWalkInCustomer(int? contactId);
  Future<int> addContactPayment(ContactPayment payment);
  Future<List<ContactPayment>> getContactPayments(int contactId);
  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(int contactId);
}

class ContactsRepository implements IContactsRepository {
  final DatabaseService _dbService;

  ContactsRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<Contact>> getContacts({String? type, String? search}) {
    return _dbService.getContacts(type: type, search: search);
  }

  @override
  Future<Contact?> getContactById(int id) => _dbService.getContactById(id);

  @override
  Future<int> addContact(Contact contact) => _dbService.addContact(contact);

  @override
  Future<int> updateContact(Contact contact) => _dbService.updateContact(contact);

  @override
  Future<int> deleteContact(int id) => _dbService.deleteContact(id);

  @override
  Future<void> updateContactBalance(int contactId, double delta) {
    return _dbService.updateContactBalance(contactId, delta);
  }

  @override
  Future<bool> isWalkInCustomer(int? contactId) => _dbService.isWalkInCustomer(contactId);

  @override
  Future<int> addContactPayment(ContactPayment payment) => _dbService.addContactPayment(payment);

  @override
  Future<List<ContactPayment>> getContactPayments(int contactId) => _dbService.getContactPayments(contactId);

  @override
  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(int contactId) {
    return _dbService.getPaymentTransactionsForContact(contactId);
  }
}
