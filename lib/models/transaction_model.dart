enum TransactionType {
  credit('credit'),
  debit('debit');

  const TransactionType(this.value);

  final String value;

  static TransactionType fromValue(String value) => switch (value) {
    'credit' => TransactionType.credit,
    'debit' => TransactionType.debit,
    _ => throw FormatException('Unsupported transaction type: $value'),
  };
}

class TransactionModel {
  const TransactionModel({
    this.id,
    required this.type,
    required this.amountPaise,
    required this.category,
    required this.date,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final TransactionType type;
  final int amountPaise;
  final String category;
  final String date;
  final String? note;
  final String createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.value,
    'amount_paise': amountPaise,
    'category': category,
    'date': date,
    'note': note,
    'created_at': createdAt,
  };

  factory TransactionModel.fromMap(Map<String, Object?> map) =>
      TransactionModel(
        id: map['id'] as int,
        type: TransactionType.fromValue(map['type'] as String),
        amountPaise: map['amount_paise'] as int,
        category: map['category'] as String,
        date: map['date'] as String,
        note: map['note'] as String?,
        createdAt: map['created_at'] as String,
      );
}
