/// Données extraites d'un ticket ou reçu via OCR.
class ParsedReceipt {
  final double? amount;
  final String? label;
  final DateTime? date;
  final String? suggestedCategory;
  final String rawText;

  const ParsedReceipt({
    this.amount,
    this.label,
    this.date,
    this.suggestedCategory,
    required this.rawText,
  });

  bool get hasData => amount != null || label != null || date != null;
}

/// Extraction heuristique depuis le texte OCR (reçus français).
class ReceiptParser {
  static const _totalKeywords = [
    'total ttc',
    'total t.t.c',
    'total à payer',
    'total a payer',
    'montant total',
    'net a payer',
    'net à payer',
    'a payer',
    'à payer',
    'total eur',
    'total €',
    'total:',
    'total ',
  ];

  static const _categoryKeywords = {
    'Alimentation': [
      'carrefour',
      'leclerc',
      'auchan',
      'lidl',
      'intermarche',
      'intermarché',
      'monoprix',
      'franprix',
      'casino',
      'super u',
      'superu',
      'picard',
      'boulangerie',
      'boucherie',
      'epicerie',
      'épicerie',
    ],
    'Transport': [
      'total',
      'shell',
      'bp ',
      ' esso',
      'sncf',
      'ratp',
      'uber',
      'bolt',
      'parking',
      'peage',
      'péage',
      'autoroute',
    ],
    'Loisirs': [
      'netflix',
      'spotify',
      'cinema',
      'cinéma',
      'fnac',
      'decathlon',
      'steam',
      'playstation',
    ],
    'Santé': ['pharmacie', 'pharmacy', 'docteur', 'medical', 'médical'],
    'Logement': ['edf', 'engie', 'loyer', 'assurance habitation'],
  };

  static ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final normalized = rawText.toLowerCase();

    return ParsedReceipt(
      amount: _extractAmount(lines, normalized),
      label: _extractLabel(lines),
      date: _extractDate(normalized),
      suggestedCategory: _suggestCategory(normalized),
      rawText: rawText,
    );
  }

  static double? _extractAmount(List<String> lines, String normalized) {
    // Priorité aux lignes contenant TOTAL / TTC / A PAYER
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_totalKeywords.any((k) => lower.contains(k))) {
        final amount = _parseAmountFromLine(line);
        if (amount != null) return amount;
      }
    }

    // Sinon le plus grand montant plausible du document
    double? maxAmount;
    for (final line in lines) {
      final amount = _parseAmountFromLine(line);
      if (amount != null && amount >= 0.01 && amount <= 50000) {
        if (maxAmount == null || amount > maxAmount) {
          maxAmount = amount;
        }
      }
    }
    return maxAmount;
  }

  static double? _parseAmountFromLine(String line) {
    final patterns = [
      RegExp(r'(\d{1,6}[,.]\d{2})\s*€'),
      RegExp(r'€\s*(\d{1,6}[,.]\d{2})'),
      RegExp(r'(?:total|ttc|payer|montant)[^\d]*(\d{1,6}[,.]\d{2})', caseSensitive: false),
      RegExp(r'(\d{1,6}[,.]\d{2})\s*(?:EUR|eur)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }
    return null;
  }

  static String? _extractLabel(List<String> lines) {
    for (final line in lines.take(8)) {
      if (line.length < 3 || line.length > 60) continue;
      if (RegExp(r'^\d').hasMatch(line)) continue;
      if (RegExp(r'(ticket|facture|reçu|recu|caisse|date|heure|tel|siret|tva|rcs)', caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      return line;
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  static DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{2})[/.-](\d{2})[/.-](\d{4})'),
      RegExp(r'(\d{2})[/.-](\d{2})[/.-](\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      var day = int.parse(match.group(1)!);
      var month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;

      try {
        return DateTime(year, month, day);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String? _suggestCategory(String text) {
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) return entry.key;
      }
    }
    return null;
  }
}
