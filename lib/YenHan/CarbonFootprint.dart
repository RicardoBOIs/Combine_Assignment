import 'package:cloud_firestore/cloud_firestore.dart';

class CarbonFootprint {
  final String uid;                 // Firebase Auth UID
  final Timestamp date;             // 00:00 of that day
  final double kgCO2e;              // daily total (kg)

  CarbonFootprint({
    required this.uid,
    required this.date,
    required this.kgCO2e,
  });

 // load from firestore to dart
  factory CarbonFootprint.fromJson(Map<String, Object?> json) =>
      CarbonFootprint(
        uid:   json['uid']   as String,
        date:  json['date']  as Timestamp,
        kgCO2e: (json['kgCO2e'] as num).toDouble(),
      );

//dart to firestore
  Map<String, Object?> toJson() => {
    'uid': uid,
    'date': date,
    'kgCO2e': kgCO2e,
  };
}
