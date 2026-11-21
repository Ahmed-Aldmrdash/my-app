import '../utils/json.dart';

enum ExpenseCategory {
  university,
  books,
  transport,
  food,
  housing,
  phone,
  courses,
  fun,
  clothes,
  health,
  other,
}

/// Money spent, in Egyptian pounds.
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.date,
    this.category = ExpenseCategory.other,
    this.title = '',
    this.subjectId,
  });

  final String id;
  final double amount;
  final ExpenseCategory category;
  final String title;
  final DateTime date;

  /// The subject it was for (a book, notes…), if any.
  final String? subjectId;

  Expense withoutSubject() => Expense(
    id: id,
    amount: amount,
    date: date,
    category: category,
    title: title,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category.name,
    'title': title,
    'date': writeDate(date),
    'subjectId': subjectId,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: readString(j['id']),
    amount: readDouble(j['amount']),
    category: enumByName(
      ExpenseCategory.values,
      j['category'],
      ExpenseCategory.other,
    ),
    title: readString(j['title']),
    date: readDate(j['date']) ?? DateTime.now(),
    subjectId: readNullableString(j['subjectId']),
  );
}
