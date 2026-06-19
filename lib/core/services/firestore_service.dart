import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/evaluation_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Save evaluation to Firestore ───────────────────────────────────────
  Future<void> saveEvaluation(EvaluationModel evaluation) async {
    await _firestore
        .collection('evaluations')
        .doc(evaluation.id)
        .set(evaluation.toMap());
  }

  // ── Fetch evaluations for exam ─────────────────────────────────────────
  Future<List<EvaluationModel>> fetchEvaluations(String examId) async {
    final snapshot = await _firestore
        .collection('evaluations')
        .where('examId', isEqualTo: examId)
        .get();

    var docs = snapshot.docs;
    docs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aTime = DateTime.tryParse(aData['evaluatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(bData['evaluatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return docs.map((doc) => EvaluationModel.fromMap(doc.data())).toList();
  }
}
