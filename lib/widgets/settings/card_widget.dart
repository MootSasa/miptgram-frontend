import 'package:flutter/material.dart';
import '../../services/database/app_database.dart';

class CardWidget extends StatelessWidget {
  final DbBankingCard card;
  final VoidCallback? onDelete;

  const CardWidget({
    super.key,
    required this.card,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Card gradients based on colorIndex
    final List<List<Color>> gradients = [
      [const Color(0xFF0D47A1), const Color(0xFF1976D2)], // Blue
      [const Color(0xFF1B5E20), const Color(0xFF43A047)], // Green
      [const Color(0xFFB71C1C), const Color(0xFFE53935)], // Red
      [const Color(0xFF4A148C), const Color(0xFF8E24AA)], // Purple
      [const Color(0xFF212121), const Color(0xFF424242)], // Black/Grey
      [const Color(0xFFBF360C), const Color(0xFFF4511E)], // Orange
    ];

    final gradient = gradients[card.colorIndex % gradients.length];

    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern or chip
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 50,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.8),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          
          // Card Type Logo
          Positioned(
            top: 20,
            right: 20,
            child: Text(
              card.cardType.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // Card Number
          Positioned(
            top: 80,
            left: 20,
            child: Text(
              _maskCardNumber(card.cardNumber),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Card Holder
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CARD HOLDER',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  card.cardHolder.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Expiry Date
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'EXPIRES',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  card.expiryDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Delete Button
          if (onDelete != null)
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: onDelete,
                tooltip: 'Delete Card',
              ),
            ),
        ],
      ),
    );
  }

  String _maskCardNumber(String number) {
    if (number.length < 12) return number;
    final clean = number.replaceAll(' ', '');
    if (clean.length != 16) return number;
    
    return '**** **** **** ${clean.substring(12)}';
  }
}
