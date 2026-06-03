import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_schema.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final double targetSugarGram;
  final int durationDays;
  final String badgeIcon;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSugarGram,
    required this.durationDays,
    required this.badgeIcon,
  });

  factory ChallengeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChallengeModel(
      id:              doc.id,
      title:           data[FSField.title] ?? '',
      description:     data[FSField.description] ?? '',
      targetSugarGram: (data[FSField.targetSugarGram] as num).toDouble(),
      durationDays:    data[FSField.durationDays] ?? 0,
      badgeIcon:       data[FSField.badgeIcon] ?? '',
    );
  }
}