import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseStatus { draft, confirmed, cancelled }

enum ExpenseCategory {
  rent,
  electricity,
  salary,
  transport,
  maintenance,
  office,
  internet,
  marketing,
  other,
}

class ExpenseModel {
  final String? expenseId;
  final String businessId;
  final DateTime expenseDate;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final ExpenseStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    this.expenseId,
    required this.businessId,
    required this.expenseDate,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw Exception('Expense data not found');

    return ExpenseModel(
      expenseId: snapshot.id,
      businessId: data['businessId'] as String,
      expenseDate: (data['expenseDate'] as Timestamp).toDate(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ExpenseCategory.other,
      ),
      description: data['description'] as String,
      amount: (data['amount'] as num).toDouble(),
      paymentMethod: data['paymentMethod'] as String,
      notes: data['notes'] as String?,
      status: ExpenseStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ExpenseStatus.draft,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (expenseId != null && expenseId!.isNotEmpty) 'expenseId': expenseId,
      'businessId': businessId,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'category': category.name,
      'description': description,
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (notes != null) 'notes': notes,
      'status': status.name,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? businessId,
    DateTime? expenseDate,
    ExpenseCategory? category,
    String? description,
    double? amount,
    String? paymentMethod,
    String? notes,
    ExpenseStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      businessId: businessId ?? this.businessId,
      expenseDate: expenseDate ?? this.expenseDate,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
