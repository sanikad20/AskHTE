import 'package:flutter/material.dart';
import '../services/orchestrator_service.dart';
import '../theme/app_theme.dart';
import 'technician/chat_screen.dart';
import 'upload_document_screen.dart';

/// AskHTE Modern Government AI Assistant Home & Navigation Shell
class AskHTEHomeScreen extends StatefulWidget {
  const AskHTEHomeScreen({super.key});

  @override
  State<AskHTEHomeScreen> createState() => _AskHTEHomeScreenState();
}

class _AskHTEHomeScreenState extends State<AskHTEHomeScreen> {
  int _currentIndex = 0;
  final _orchestrator = OrchestratorService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _recentDocs = [];
  bool _loadingDocs = false;

  final List<String> _recentQueries = [
    '📄 What is this Government Resolution about?',
    '📝 Summarize this document.',
    '👥 Who is eligible under this scheme?',
    '📚 What are the key decisions in this GR?',
  ];


  @override
  void initState() {
    super.initState();
    _fetchRecentDocs();
  }

  Future<void> _fetchRecentDocs() async {
    setState(() => _loadingDocs = true);
    try {
      final docs = await _orchestrator.listDocuments();
      if (mounted) {
        setState(() {
          _recentDocs = docs;
          _loadingDocs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  void _navigateToChatWithQuery([String? initialQuery]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialQuery: initialQuery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeDashboard(context),
          const ChatScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.8)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
              label: 'AI Chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRecentDocs,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Banner Card (Responsive Header & Emblem)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F766E), const Color(0xFF1E293B)]
                        : [const Color(0xFF0F766E), const Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  const Text(
                                    'AskHTE',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'GOV AI',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'AI Powered Government Assistant',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ask official circulars & GRs. Get cited, trusted answers grounded strictly in authenticated government documents.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Clean Gemini/ChatGPT Style Pill Search Bar (No Grey Box, Height 56, Radius 28)
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: 'Search Government Circulars, GRs, Schemes...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textFaint),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 10),
                      child: Icon(Icons.search, color: AppColors.primary, size: 22),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final text = _searchController.text.trim();
                            if (text.isNotEmpty) {
                              _navigateToChatWithQuery(text);
                            } else {
                              _navigateToChatWithQuery();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _navigateToChatWithQuery(val.trim());
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 3. "Why AskHTE?" Informational Section (4 Equal Feature Cards)
              const Text(
                'Why AskHTE?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Trusted AI features built for Maharashtra HTE Department',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
              const SizedBox(height: 12),

              // 4 Informational Feature Cards (Zero Overflow Layout)
              LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _WhyAskHteCard(
                              title: 'Verified Sources',
                              subtitle: 'Answers grounded only in official Government GRs.',
                              icon: Icons.verified,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WhyAskHteCard(
                              title: 'Multilingual AI',
                              subtitle: 'Supports English, Marathi and Hindi.',
                              icon: Icons.language,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _WhyAskHteCard(
                              title: 'Document Intelligence',
                              subtitle: 'Summarize, compare and understand official documents.',
                              icon: Icons.description,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WhyAskHteCard(
                              title: 'Source Citations',
                              subtitle: 'Every answer includes references and confidence score.',
                              icon: Icons.article,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // 4. Suggested & Recent Queries Section (Wrapped in Expanded to fix 2.1px overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Suggested & Recent Queries',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _navigateToChatWithQuery(),
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text('Open Chat'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                children: _recentQueries
                    .map(
                      (q) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_outlined, size: 18, color: AppColors.primary),
                          title: Text(
                            q,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.north_east, size: 16, color: AppColors.textFaint),
                          onTap: () => _navigateToChatWithQuery(q),
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 20),

              // 5. Ingested Government Documents Section (Wrapped in Expanded to prevent overflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Ingested Government Documents',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.upload_file_outlined, color: AppColors.primary),
                    tooltip: 'Upload Document',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
                    ).then((_) => _fetchRecentDocs()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_loadingDocs)
                const LinearProgressIndicator(color: AppColors.primary)
              else if (_recentDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.folder_open_outlined, size: 40, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 10),
                      const Text(
                        'No ingested documents yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload official circulars or GR PDFs to enable grounded QA.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
                        ).then((_) => _fetchRecentDocs()),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Upload PDF'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _recentDocs
                      .map(
                        (d) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                            title: Text(
                              d['fileName'] as String? ?? 'Document',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              d['primaryRef'] != null ? 'Ref: ${d['primaryRef']}' : 'Ingested Government Resolution',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Ingested 🔒',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Informational Feature Card for "Why AskHTE?" Section (Informational Only - Equal Height Cards)
class _WhyAskHteCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _WhyAskHteCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint, height: 1.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
