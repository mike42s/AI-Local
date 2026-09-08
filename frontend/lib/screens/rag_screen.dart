import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../providers/rag_provider.dart';

class RagScreen extends ConsumerStatefulWidget {
  const RagScreen({super.key});

  @override
  ConsumerState<RagScreen> createState() => _RagScreenState();
}

class _RagScreenState extends ConsumerState<RagScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Direct Attachment State
  Uint8List? _attachedPdfBytes;
  String? _attachedPdfName;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickPdfAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _attachedPdfBytes = file.bytes;
            _attachedPdfName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memilih lampiran PDF: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    final hasPdf = _attachedPdfBytes != null;

    if (userText.isEmpty && !hasPdf) return;

    _controller.clear();

    final pdfBytes = _attachedPdfBytes;
    final pdfName = _attachedPdfName;

    setState(() {
      _attachedPdfBytes = null;
      _attachedPdfName = null;
    });

    // Formulate prompt
    String promptToSend = userText;
    if (promptToSend.isEmpty && hasPdf) {
      promptToSend =
          'Evaluasi kualifikasi CV pelamar "${pdfName ?? 'Kandidat'}" ini secara komprehensif, sebutkan kelebihan, kekurangan, dan berikan skor kecocokan Match Score 1-100.';
    }

    // Send candidate PDF directly on-the-fly to stream endpoint without polluting pgvector DB
    ref.read(ragProvider.notifier).sendMessageStream(
          promptToSend,
          candidatePdfBytes: pdfBytes,
        );
    _scrollToBottom();
  }

  void _showIngestModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _IngestModalContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ragState = ref.watch(ragProvider);

    ref.listen(ragProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length || next.isStreaming) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HR Candidate Screening & RAG',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'pgvector DB (Port 5433) • 1-100 Grading • PDF Ingest',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'Ingest CV PDF / Dokumen Baru',
            onPressed: () => _showIngestModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus Chat',
            onPressed: () {
              ref.read(ragProvider.notifier).clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (ragState.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                ragState.errorMessage!,
                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
              ),
            ),
          Expanded(
            child: ragState.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.teal.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'Sistem Evaluasi HRD & Filtering Pelamar AI',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Lampirkan file PDF CV langsung pada kolom chat atau tanyakan kriteria posisi. AI akan memberikan skor match 1-100 secara real-time.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.attach_file, size: 16),
                                label: const Text('Lampirkan PDF CV di Chat'),
                                onPressed: _pickPdfAttachment,
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.upload_file, size: 16),
                                label: const Text('Ingest Dokumen Base'),
                                onPressed: () => _showIngestModal(context),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.question_answer_outlined, size: 16),
                                label: const Text('Apa syarat IT Supervisor?'),
                                onPressed: () {
                                  _controller.text = 'Apa syarat pendidikan dan keahlian untuk posisi IT Developer SPV?';
                                  _sendMessage();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: ragState.messages.length,
                    itemBuilder: (context, index) {
                      final message = ragState.messages[index];
                      return _RagChatBubble(message: message);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_attachedPdfName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Lampiran CV: $_attachedPdfName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _attachedPdfBytes = null;
                                _attachedPdfName = null;
                              });
                            },
                            child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.teal),
                        tooltip: 'Lampirkan File PDF CV Pelamar',
                        onPressed: ragState.isStreaming ? null : _pickPdfAttachment,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _attachedPdfName != null
                                ? 'Tuliskan instruksi analisis (opsional)...'
                                : 'Tanyakan evaluasi pelamar / kriteria posisi...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: ragState.isStreaming ? null : _sendMessage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        icon: ragState.isStreaming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngestModalContent extends StatefulWidget {
  const _IngestModalContent();

  @override
  State<_IngestModalContent> createState() => _IngestModalContentState();
}

class _IngestModalContentState extends State<_IngestModalContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // PDF Tab State
  final _pdfTitleController = TextEditingController();
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfName;

  // Text Tab State
  final _textTitleController = TextEditingController();
  final _textContentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pdfTitleController.dispose();
    _textTitleController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedPdfBytes = file.bytes;
            _selectedPdfName = file.name;
            if (_pdfTitleController.text.trim().isEmpty) {
              _pdfTitleController.text = file.name.replaceAll('.pdf', '');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memilih file PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final ragState = ref.watch(ragProvider);

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📥 Ingest CV / Dokumen RAG',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelColor: Colors.teal,
                indicatorColor: Colors.teal,
                tabs: const [
                  Tab(icon: Icon(Icons.picture_as_pdf), text: 'Upload File PDF CV'),
                  Tab(icon: Icon(Icons.text_fields), text: 'Input Teks / SOP Base'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // PDF Upload Tab
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickPdfFile,
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            label: Text(
                              _selectedPdfName == null
                                  ? 'Pilih File PDF CV Pelamar'
                                  : 'Terpilih: $_selectedPdfName',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pdfTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Pelamar / Title CV (mis. CV_Ryan_IT)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (ragState.isIngesting || _selectedPdfBytes == null)
                                  ? null
                                  : () async {
                                      final title = _pdfTitleController.text.trim();
                                      final success = await ref
                                          .read(ragProvider.notifier)
                                          .ingestPdfDocument(
                                            pdfBytes: _selectedPdfBytes!,
                                            title: title.isEmpty ? _selectedPdfName : title,
                                          );
                                      if (success && context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ref.read(ragProvider).ingestMessage ??
                                                  'PDF CV berhasil di-ingest ke pgvector!',
                                            ),
                                            backgroundColor: Colors.green.shade700,
                                          ),
                                        );
                                      }
                                    },
                              icon: ragState.isIngesting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.picture_as_pdf),
                              label: Text(ragState.isIngesting
                                  ? 'Mengekstrak PDF & Embedding...'
                                  : 'Proses & Simpan PDF ke pgvector DB'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Manual Text Tab
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _textTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Judul Dokumen / Syarat Jabatan (mis. Syarat_IT_Spv)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textContentController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Konten Teks Syarat Jabatan / SOP Base Data (ID / EN)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: ragState.isIngesting
                                  ? null
                                  : () async {
                                      final text = _textContentController.text.trim();
                                      final title = _textTitleController.text.trim();
                                      if (text.isNotEmpty) {
                                        final success = await ref
                                            .read(ragProvider.notifier)
                                            .ingestDocument(
                                              content: text,
                                              title: title.isEmpty ? null : title,
                                            );
                                        if (success && context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ref.read(ragProvider).ingestMessage ??
                                                    'Dokumen teks berhasil di-ingest!',
                                              ),
                                              backgroundColor: Colors.green.shade700,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: ragState.isIngesting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.storage),
                              label: Text(ragState.isIngesting ? 'Memproses Vector...' : 'Simpan Teks ke pgvector DB'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RagChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _RagChatBubble({required this.message});

  Widget? _buildScoreBadge(String text) {
    final regExp = RegExp(r'\[MATCH SCORE:\s*(\d{1,3})/100\]', caseSensitive: false);
    final match = regExp.firstMatch(text);
    if (match == null) return null;

    final scoreStr = match.group(1);
    final score = int.tryParse(scoreStr ?? '0') ?? 0;

    Color badgeColor = Colors.green.shade800;
    String statusLabel = 'Sangat Layak / High Match';

    if (score < 60) {
      badgeColor = Colors.red.shade800;
      statusLabel = 'Kurang Sesuai / Low Match';
    } else if (score < 80) {
      badgeColor = Colors.amber.shade900;
      statusLabel = 'Dipertimbangkan / Medium Match';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(20),
        border: Border.all(color: badgeColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, color: badgeColor, size: 22),
          const SizedBox(width: 8),
          Text(
            'SCORE: $score/100',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '• $statusLabel',
            style: TextStyle(fontSize: 12, color: badgeColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final scoreBadge = !isUser ? _buildScoreBadge(message.text) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.badge, size: 18, color: Colors.teal),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Bright, clear background for AI message response bubble for high readability
                color: isUser ? Colors.teal.shade700 : Colors.grey.shade100,
                border: isUser ? null : Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?scoreBadge,
                  if (message.text.isEmpty && message.isStreaming)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mencari konteks di pgvector DB & menganalisis...',
                          style: TextStyle(
                            color: isUser ? Colors.white70 : Colors.black54,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  else
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        // High contrast dark text for AI answer on bright background
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  if (message.isStreaming && message.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade900,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
