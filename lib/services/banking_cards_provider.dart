import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'database/app_database.dart';
import 'package:uuid/uuid.dart';
import 'wallet_security_provider.dart';

class BankingCardsProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  List<DbBankingCard> _cards = [];
  bool _isLoading = false;
  WalletSecurityProvider? _securityProvider;

  List<DbBankingCard> get cards => _cards;
  bool get isLoading => _isLoading;

  void update(WalletSecurityProvider securityProvider) {
    _securityProvider = securityProvider;
    if (securityProvider.isUnlocked) {
      loadCards();
    } else {
      _cards = [];
      notifyListeners();
    }
  }

  Future<void> loadCards() async {
    if (_securityProvider == null || !_securityProvider!.isUnlocked) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final rawCards = await _db.getBankingCards();
      _cards = rawCards.map((dbCard) {
        return dbCard.copyWith(
          cardNumber: _securityProvider!.decryptData(dbCard.cardNumber),
          cardHolder: _securityProvider!.decryptData(dbCard.cardHolder),
          expiryDate: _securityProvider!.decryptData(dbCard.expiryDate),
        );
      }).toList();
    } catch (e) {
      debugPrint('BankingCardsProvider: Error loading cards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCard({
    required String cardNumber,
    required String cardHolder,
    required String expiryDate,
    required String cardType,
    int colorIndex = 0,
  }) async {
    if (_securityProvider == null || !_securityProvider!.isUnlocked) {
      throw Exception('Wallet not unlocked');
    }

    final encryptedNumber = _securityProvider!.encryptData(cardNumber);
    final encryptedHolder = _securityProvider!.encryptData(cardHolder);
    final encryptedExpiry = _securityProvider!.encryptData(expiryDate);

    final companion = BankingCardsCompanion(
      cardId: Value(const Uuid().v4()),
      cardNumber: Value(encryptedNumber),
      cardHolder: Value(encryptedHolder),
      expiryDate: Value(encryptedExpiry),
      cardType: Value(cardType),
      colorIndex: Value(colorIndex),
      createdAt: Value(DateTime.now().toIso8601String()),
    );

    try {
      await _db.saveBankingCard(companion);
      await loadCards();
    } catch (e) {
      debugPrint('BankingCardsProvider: Error adding card: $e');
      rethrow;
    }
  }

  Future<void> deleteCard(int id) async {
    try {
      await _db.deleteBankingCard(id);
      await loadCards();
    } catch (e) {
      debugPrint('BankingCardsProvider: Error deleting card: $e');
      rethrow;
    }
  }
}
