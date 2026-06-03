import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_schema.dart';

class SugarLogModel {
  final String id;
  final String userId;
  final String productName;
  final double portionGram;
  final double sugarGram;
  final String source; // 'api' atau 'manual'
  final DateTime loggedAt;

  SugarLogModel({
    required this.id,
    required this.userId,
    required this.productName,
    required this.portionGram,
    required this.sugarGram,
    required this.source,
    required this.loggedAt,
  });

  factory SugarLogModel.fromFirestore(
      DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SugarLogModel(
      id:          doc.id,
      userId:      data[FSField.userId] ?? '',
      productName: data[FSField.productName] ?? '',
      portionGram: (data[FSField.portionGram] as num).toDouble(),
      sugarGram:   (data[FSField.sugarGram] as num).toDouble(),
      source:      data[FSField.source] ?? 'manual',
      loggedAt:    (data[FSField.loggedAt] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    FSField.userId:      userId,
    FSField.productName: productName,
    FSField.portionGram: portionGram,
    FSField.sugarGram:   sugarGram,
    FSField.source:      source,
    FSField.loggedAt:    Timestamp.fromDate(loggedAt),
  };
}