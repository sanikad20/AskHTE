import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/chat_message.dart';
import '../../services/orchestrator_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/explainable_ai_panel.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/relationship_timeline_card.dart';
import '../upload_document_screen.dart';

/// Knowledge Agent chat — text + voice input. Logic unchanged from
/// Day 3; this pass is purely the professional UI restyle plus the
/// Day 4 AccountMenu (role display + sign out).
class ChatScreen extends StatefulWidget {
  final String userRole;
  const ChatScreen({super.key, this.userRole = 'technician'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _orchestrator = OrchestratorService();
  final _textController = TextEditingController();
  final _equipmentIdController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = stt.SpeechToText();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _selectedLanguage = 'Auto'; // Auto | English | Marathi | Hindi

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input unavailable on this device/browser.')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
  }

  Future<void> _send() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _isSending) return;

    final equipmentId = _equipmentIdController.text.trim();
    final targetLang = _selectedLanguage == 'Auto' ? null : _selectedLanguage;

    setState(() {
      _messages.add(ChatMessage(text: query, isUser: true));
      _isSending = true;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final response = await _orchestrator.query(
        query,
        userRole: widget.userRole,
        equipmentId: equipmentId.isEmpty ? null : equipmentId,
        targetLanguage: targetLang,
      );
      setState(() {
        _messages.add(ChatMessage.fromOrchestratorResponse(response));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Could not reach AskHTE: $e',
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _openSummarizeModal() async {
    try {
      final docs = await _orchestrator.listDocuments();
      if (!mounted) return;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents ingested yet. Upload a document first.')),
        );
        return;
      }

      String selectedDocId = docs.first['docId'] as String;
      String detailLevel = 'short';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.summarize_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Summarize Document'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Document:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedDocId,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Document', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Summary Depth:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Concise'),
                      selected: detailLevel == 'short',
                      onSelected: (sel) {
                        if (sel) setModalState(() => detailLevel = 'short');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Detailed'),
                      selected: detailLevel == 'detailed',
                      onSelected: (sel) {
                        if (sel) setModalState(() => detailLevel = 'detailed');
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isSending = true);
                  try {
                    final summaryData = await _orchestrator.summarizeDocument(selectedDocId, detailLevel: detailLevel);
                    final summaryText = "📄 Document Summary (${summaryData['fileName']}):\n\n"
                        "${summaryData['summary']}\n\n"
                        "📌 Key Points:\n${(summaryData['keyPoints'] as List).map((k) => '• $k').join('\n')}\n\n"
                        "🗓 Effective Date: ${summaryData['effectiveDate'] ?? 'N/A'}\n"
                        "👥 Applicability: ${summaryData['applicability'] ?? 'N/A'}";

                    setState(() {
                      _messages.add(ChatMessage(
                        text: summaryText,
                        isUser: false,
                        confidence: 0.98,
                        sources: [summaryData['fileName'] as String? ?? 'Document'],
                        reasoning: 'Generated AI document summary using Llama 3.3 70B.',
                      ));
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to generate summary: $e')),
                    );
                  } finally {
                    setState(() => _isSending = false);
                    _scrollToBottom();
                  }
                },
                child: const Text('Generate Summary'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not list documents: $e')),
      );
    }
  }

  void _openCompareModal() async {
    try {
      final docs = await _orchestrator.listDocuments();
      if (!mounted) return;

      if (docs.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload at least 2 documents to compare.')),
        );
        return;
      }

      String docA = docs[0]['docId'] as String;
      String docB = docs[1]['docId'] as String;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.compare_arrows_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Compare Documents'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Document A (Original):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: docA,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Doc A', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => docA = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Document B (Updated/Comparison):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: docB,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Doc B', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => docB = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isSending = true);
                  try {
                    final compData = await _orchestrator.compareDocuments(docA, docB);
                    final fileA = compData['file_a'] ?? 'Document A';
                    final fileB = compData['file_b'] ?? 'Document B';

                    final compText = "⚖️ Document Comparison:\n"
                        "Comparing $fileA ⚡ $fileB\n\n"
                        "➕ Added Clauses:\n${(compData['added_clauses'] as List).map((c) => '• $c').join('\n')}\n\n"
                        "➖ Removed/Superseded Clauses:\n${(compData['removed_clauses'] as List).map((c) => '• $c').join('\n')}\n\n"
                        "✏️ Modified Provisions:\n${(compData['modified_clauses'] as List).map((c) => '• $c').join('\n')}\n\n"
                        "💡 Policy Differences:\n${(compData['policy_differences'] as List).map((c) => '• $c').join('\n')}";

                    setState(() {
                      _messages.add(ChatMessage(
                        text: compText,
                        isUser: false,
                        confidence: 0.96,
                        sources: [fileA as String, fileB as String],
                        reasoning: 'Extracted clause-level comparison and policy differences.',
                      ));
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to compare documents: $e')),
                    );
                  } finally {
                    setState(() => _isSending = false);
                    _scrollToBottom();
                  }
                },
                child: const Text('Compare Documents'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not list documents: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AskHTE'),
        actions: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.summarize_outlined),
                    tooltip: 'Summarize Document',
                    onPressed: _openSummarizeModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.compare_arrows_outlined),
                    tooltip: 'Compare Documents',
                    onPressed: _openCompareModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file_outlined),
                    tooltip: 'Upload a document',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.language_outlined),
                    tooltip: 'Target Response Language',
                    onSelected: (lang) {
                      setState(() => _selectedLanguage = lang);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Response language set to: $lang')),
                      );
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'Auto', child: Text('🌐 Auto-Detect')),
                      const PopupMenuItem(value: 'English', child: Text('🇬🇧 English')),
                      const PopupMenuItem(value: 'Marathi', child: Text('🇮🇳 मराठी (Marathi)')),
                      const PopupMenuItem(value: 'Hindi', child: Text('🇮🇳 हिंदी (Hindi)')),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 4, left: 4),
                    child: AccountMenu(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: AppColors.surface,
            child: TextField(
              controller: _equipmentIdController,
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(
                labelText: 'Reference No. (optional)',
                hintText: 'e.g. CIRCULAR-2026/45',
                isDense: true,
                prefixIcon: Icon(Icons.tag, size: 18),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: AppColors.background,
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
                    ),
            ),
          ),
          if (_isSending)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _isListening ? AppColors.dangerBg : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _toggleListening,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? AppColors.danger : AppColors.primary,
                ),
                tooltip: 'Ask by voice',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(
                  hintText: 'Ask about HTE circulars — e.g. "What is the last date for the scholarship scheme?"',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: IconButton(
                onPressed: _isSending ? null : _send,
                icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // FIX: this is the "BOTTOM OVERFLOWED BY 56 PIXELS" seen in the
    // screenshot. Cause: a centered Column with icon + heading +
    // subtitle had no scroll fallback, so when the keyboard opened
    // (from focusing the Equipment ID field above) and shrank the
    // Expanded area this sits in, the content no longer fit.
    //
    // Fix: LayoutBuilder + SingleChildScrollView + ConstrainedBox
    // (minHeight) — when there's enough room it still centers exactly
    // as before; when space is tight, it scrolls instead of
    // overflowing. Same icon, same text, same spacing.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hub_outlined, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Ask AskHTE', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Type a question or tap the mic. Answers are\ngrounded in ingested HTE circulars, GRs, and notices.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
        ),
      );
    }

    final bgColor = message.isError ? AppColors.dangerBg : AppColors.surface;
    final borderColor = message.isError ? AppColors.danger.withOpacity(0.3) : AppColors.border;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && !message.isError) ...[
              Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.hub_outlined, size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'AskHTE',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              cleanDevanagari(message.text),
              style: TextStyle(
                fontSize: 14.5,
                color: message.isError ? AppColors.danger : AppColors.textPrimary,
                fontFamilyFallback: const [
                  'Noto Sans Devanagari',
                  'NotoSansDevanagari',
                  'Roboto',
                  'sans-serif',
                ],
              ),
            ),

            if (!isUser && !message.isError) ...[
              const SizedBox(height: 10),
              ExplainableAiPanel(
                confidence: message.confidence ?? 0.0,
                sources: message.sources,
                reasoning: message.reasoning,
                pageCitations: message.pageCitations,
                detectedLanguage: message.detectedLanguage,
                administrativeRecommendations: message.administrativeRecommendations,
                timeline: message.timeline
                    .map((t) => TimelineEntry(
                          ref: t['ref'] as String? ?? t['doc_id'] as String? ?? 'Unknown',
                          date: t['date'] as String? ?? '',
                          relationToPrevious: t['relation_to_previous'] as String?,
                        ))
                    .toList(),
                conflicts: message.conflicts
                    .map((c) => ConflictEntry(
                          docA: c['doc_a'] as String? ?? 'Unknown',
                          dateA: c['date_a'] as String? ?? '',
                          docB: c['doc_b'] as String? ?? 'Unknown',
                          dateB: c['date_b'] as String? ?? '',
                          topicHint: c['topic_hint'] as String? ?? '',
                        ))
                    .toList(),
              ),

            ],
          ],
        ),
      ),
    );
  }
}