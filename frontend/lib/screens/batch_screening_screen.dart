import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rag_provider.dart';

class BatchScreeningScreen extends ConsumerStatefulWidget {
  const BatchScreeningScreen({super.key});
  @override
  ConsumerState<BatchScreeningScreen> createState() => _BatchScreeningScreenState();
}

class _BatchScreeningScreenState extends ConsumerState<BatchScreeningScreen> {
  final _promptController = TextEditingController();
  final List<CandidatePdf> _candidates = [];
  @override
  void dispose() { _promptController.dispose(); super.dispose(); }

  Future<void> _pickCvs() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true, withData: true);
    if (result == null) return;
    setState(() {
      for (final file in result.files.where((file) => file.bytes != null)) {
        if (_candidates.length == 10) break;
        _candidates.add(CandidatePdf(name: file.name, bytes: Uint8List.fromList(file.bytes!)));
      }
    });
  }

  Future<void> _evaluate() async {
    final success = await ref.read(ragProvider.notifier).evaluateCandidatesBatch(prompt: _promptController.text, candidates: _candidates);
    if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(ragProvider).errorMessage ?? 'Batch screening gagal.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ragProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Batch CV Screening')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Pilih hingga 10 CV PDF. Nama file menjadi identitas kandidat pada hasil skoring.'),
        const SizedBox(height: 12),
        TextField(controller: _promptController, maxLines: 2, decoration: const InputDecoration(labelText: 'Posisi atau instruksi evaluasi', hintText: 'Contoh: Evaluasi untuk posisi IT Supervisor', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: state.isBatchEvaluating ? null : _pickCvs, icon: const Icon(Icons.upload_file), label: Text('Pilih beberapa CV PDF (${_candidates.length}/10)')),
        ..._candidates.asMap().entries.map((entry) => ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), title: Text(entry.value.name), trailing: IconButton(icon: const Icon(Icons.close), onPressed: state.isBatchEvaluating ? null : () => setState(() => _candidates.removeAt(entry.key))))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _candidates.isEmpty || state.isBatchEvaluating ? null : _evaluate, icon: state.isBatchEvaluating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assessment), label: Text(state.isBatchEvaluating ? 'Mengevaluasi CV satu per satu...' : 'Mulai Batch Screening')),
        if (state.batchResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Hasil Screening', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...state.batchResults.map((result) => _ResultCard(result: result)),
        ],
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final CandidateEvaluation result;
  const _ResultCard({required this.result});
  @override
  Widget build(BuildContext context) {
    final scoreColor = result.score == null ? Colors.grey : result.score! >= 80 ? Colors.green : result.score! >= 60 ? Colors.orange : Colors.red;
    return Card(child: ExpansionTile(
      leading: CircleAvatar(backgroundColor: scoreColor.withAlpha(30), child: Text(result.score?.toString() ?? '-')),
      title: Text(result.name), subtitle: Text(result.error ?? result.recommendation),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [_Section(title: 'Kelebihan', items: result.strengths, empty: 'Belum ditemukan.'), _Section(title: 'Kekurangan / Gap', items: result.gaps, empty: 'Tidak ada gap yang disebutkan.')],
    ));
  }
}

class _Section extends StatelessWidget {
  final String title; final List<String> items; final String empty;
  const _Section({required this.title, required this.items, required this.empty});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(items.isEmpty ? empty : items.map((item) => '• $item').join('\n'))]));
}
