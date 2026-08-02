import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/chat_message.dart';
import '../../services/orchestrator_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/explainable_ai_panel.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/relationship_timeline_card.dart';
import '../upload_document_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userRole;
  final String? initialQuery;

  const ChatScreen({
    super.key,
    this.userRole = 'technician',
    this.initialQuery,
  });

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
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _textController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _send();
      });
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = cleanDevanagari(result.recognizedWords);
          });
        },
      );
    }
  }

  Future<void> _send([String? overrideText]) async {
    final text = cleanDevanagari(overrideText ?? _textController.text.trim());
    if (text.isEmpty || _isSending) return;

    final eqId = _equipmentIdController.text.trim().isEmpty ? null : _equipmentIdController.text.trim();

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final res = await _orchestrator.query(
        text,
        equipmentId: eqId,
        userRole: widget.userRole,
        targetLanguage: _selectedLanguage == 'Auto' ? null : _selectedLanguage,
      );

      final reply = ChatMessage.fromOrchestratorResponse(res);
      setState(() {
        _messages.add(reply);
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error querying AskHTE: $e',
          isUser: false,
          isError: true,
        ));
        _isSending = false;
      });
    }
    _scrollToBottom();
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

  Future<void> _showDocumentSummarizerDialog() async {
    try {
      final docs = await _orchestrator.listDocuments();
      if (!mounted) return;
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No documents ingested yet. Please upload a PDF circular first.')),
        );
        return;
      }

      String? selectedDoc = docs.first['docId'] as String?;
      String detailLevel = 'short';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.summarize, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Summarize Government Circular'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Document:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedDoc,
                  isExpanded: true,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Untitled', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedDoc = val),
                ),
                const SizedBox(height: 14),
                const Text('Summary Depth:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  children: [
                    Radio<String>(
                      value: 'short',
                      groupValue: detailLevel,
                      onChanged: (v) => setDialogState(() => detailLevel = v!),
                    ),
                    const Text('Concise (Short)'),
                    const SizedBox(width: 12),
                    Radio<String>(
                      value: 'detailed',
                      groupValue: detailLevel,
                      onChanged: (v) => setDialogState(() => detailLevel = v!),
                    ),
                    const Text('Detailed'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedDoc == null
                    ? null
                    : () async {
                        Navigator.pop(dialogCtx);
                        _fetchAndShowSummary(selectedDoc!, detailLevel);
                      },
                child: const Text('Generate Summary'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load documents: $e')));
    }
  }

  Future<void> _fetchAndShowSummary(String docId, String detailLevel) async {
    setState(() => _isSending = true);
    try {
      final summary = await _orchestrator.summarizeDocument(docId, detailLevel: detailLevel);

      setState(() => _isSending = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.description, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary['fileName'] as String? ?? 'Document Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                color: AppColors.primary.withOpacity(0.06),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EXECUTIVE SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 6),
                      Text(
                        cleanDevanagari(summary['summary'] as String? ?? ''),
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              if ((summary['keyPoints'] as List? ?? []).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Key Bullet Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ...List<String>.from(summary['keyPoints'] as List).map(
                  (kp) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cleanDevanagari(kp), style: const TextStyle(fontSize: 13.5))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate summary: $e')));
    }
  }

  Future<void> _showDocumentCompareDialog() async {
    try {
      final docs = await _orchestrator.listDocuments();
      if (!mounted) return;
      if (docs.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Need at least 2 ingested documents to perform side-by-side comparison.')),
        );
        return;
      }

      String? docA = docs[0]['docId'] as String?;
      String? docB = docs[1]['docId'] as String?;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.compare_arrows, color: AppColors.accent),
                SizedBox(width: 8),
                Text('Compare Circulars / GRs'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Document A (Base):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButtonFormField<String>(
                  value: docA,
                  isExpanded: true,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Doc A', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => docA = val),
                ),
                const SizedBox(height: 12),
                const Text('Document B (Target):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButtonFormField<String>(
                  value: docB,
                  isExpanded: true,
                  items: docs
                      .map((d) => DropdownMenuItem<String>(
                            value: d['docId'] as String,
                            child: Text(d['fileName'] as String? ?? 'Doc B', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => docB = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (docA == null || docB == null || docA == docB)
                    ? null
                    : () {
                        Navigator.pop(dialogCtx);
                        _fetchAndShowCompare(docA!, docB!);
                      },
                child: const Text('Compare Now'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load comparison: $e')));
    }
  }

  Future<void> _fetchAndShowCompare(String docA, String docB) async {
    setState(() => _isSending = true);
    try {
      final comp = await _orchestrator.compareDocuments(docA, docB);

      setState(() => _isSending = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text('Document Clause Comparison', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${comp['fileA']} vs ${comp['fileB']}', style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
              const SizedBox(height: 16),

              // Green Added Clauses
              _DiffSection(
                title: '➕ Added Clauses',
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                items: List<String>.from(comp['addedClauses'] ?? []),
              ),
              const SizedBox(height: 12),

              // Red Removed Clauses
              _DiffSection(
                title: '➖ Removed / Superseded Clauses',
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                items: List<String>.from(comp['removedClauses'] ?? []),
              ),
              const SizedBox(height: 12),

              // Yellow Modified Clauses
              _DiffSection(
                title: '✏️ Modified Provisions',
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                items: List<String>.from(comp['modifiedClauses'] ?? []),
              ),
              const SizedBox(height: 12),

              // Policy Differences
              _DiffSection(
                title: '💡 Administrative Policy Differences',
                color: AppColors.accent,
                bgColor: AppColors.accent.withOpacity(0.06),
                items: List<String>.from(comp['policyDifferences'] ?? []),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to compare documents: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AskHTE AI Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    'Grounded in Official GRs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'Summarize Circular',
            onPressed: _showDocumentSummarizerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare Circulars',
            onPressed: _showDocumentCompareDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Select Response Language',
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
            padding: EdgeInsets.only(right: 4),
            child: AccountMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Optional Reference ID bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                const Icon(Icons.tag, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _equipmentIdController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Filter by Reference No. (e.g. GR-2026/45, optional)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Message List
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _MessageBubble(
                        message: msg,
                        onRegenerate: () => _send(msg.text),
                      );
                    },
                  ),
          ),

          // Shimmer loading animation during generation
          if (_isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withOpacity(0.04),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Searching authenticated circulars & generating cited response…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Voice listening status bar
          if (_isListening)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade50,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Listening in Marathi / Hindi / English…', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),

          // Rounded Pill Input Bar (Radius 30, Soft Shadow, Circular Mic & Send buttons)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Circular Microphone Button
                Material(
                  color: _isListening ? Colors.red.shade100 : AppColors.primary.withOpacity(0.1),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleListening,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _isListening ? Icons.mic_off : Icons.mic,
                        color: _isListening ? Colors.red : AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pill TextField Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask in English, मराठी, or हिंदी…',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textFaint),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Circular Send Button
                Material(
                  color: _isSending ? Colors.grey.shade400 : AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isSending ? null : () => _send(),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );

  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'How can AskHTE help you today?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ask questions in English, Marathi, or Hindi. All answers carry source citations and confidence scores.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onRegenerate;

  const _MessageBubble({
    required this.message,
    required this.onRegenerate,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    final cleanText = cleanDevanagari(message.text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : (message.isError ? AppColors.dangerBg : Theme.of(context).cardColor),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: Border.all(
            color: isUser ? AppColors.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && !message.isError) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.hub_outlined, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text('AskHTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, size: 11, color: Color(0xFF10B981)),
                        SizedBox(width: 3),
                        Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    tooltip: _isExpanded ? 'Collapse' : 'Expand',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Message text
            Text(
              cleanText,
              maxLines: _isExpanded ? null : 4,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: isUser ? Colors.white : (message.isError ? AppColors.danger : null),
                fontFamilyFallback: AppTheme.devanagariFontFallback,
              ),
            ),

            if (!isUser && !message.isError) ...[
              const SizedBox(height: 12),
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

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Action Toolbar: Copy, Share, Regenerate, Like/Dislike
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    tooltip: 'Copy Answer',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cleanText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Answer copied to clipboard!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    tooltip: 'Regenerate Answer',
                    onPressed: widget.onRegenerate,
                  ),
                  IconButton(
                    icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: _isLiked ? AppColors.primary : null),
                    onPressed: () => setState(() {
                      _isLiked = !_isLiked;
                      if (_isLiked) _isDisliked = false;
                    }),
                  ),
                  IconButton(
                    icon: Icon(_isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined, size: 16, color: _isDisliked ? AppColors.danger : null),
                    onPressed: () => setState(() {
                      _isDisliked = !_isDisliked;
                      if (_isDisliked) _isLiked = false;
                    }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiffSection extends StatelessWidget {
  final String title;
  final Color color;
  final Color bgColor;
  final List<String> items;

  const _DiffSection({
    required this.title,
    required this.color,
    required this.bgColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(cleanDevanagari(item), style: const TextStyle(fontSize: 13, height: 1.35))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}