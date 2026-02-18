// ignore_for_file: file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multiwordexpressionworkbench/services/annotationService.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/annotateSentencePage.dart';
import 'package:multiwordexpressionworkbench/ui/contact_us.dart';
import 'package:multiwordexpressionworkbench/ui/feedback.dart';
import 'package:multiwordexpressionworkbench/ui/home_page.dart';
import 'package:multiwordexpressionworkbench/ui/overlays/addProjectOverlay.dart';
import 'package:multiwordexpressionworkbench/ui/profile_page.dart';
import '../fetchData/fetchProjectItems.dart';
import '../fetchData/fetchSentenceItems.dart';
import '../models/project.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/sentence_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const sidebar = Color(0xFF12131A);
  static const sidebarAccent = Color(0xFF1E2030);
  static const primary = Color(0xFF7C5CFC); // Purple accent for MWE
  static const primaryLight = Color(0xFFF0ECFF);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFFE4E4);
  static const warning = Color(0xFFF59E0B);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const cardShadow = Color(0x0A000000);
}

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  _ProjectsPageState createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage>
    with SingleTickerProviderStateMixin {
  List<Project> projects = [];
  List<Sentence> sentences = [];
  int currentPage = 0;
  final int itemsPerPage = 6;
  final AnnotationService annotationService = AnnotationService();
  final secureStorage = FlutterSecureStorage();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool isLoading = true;
  String? userRole;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _checkIfTokenExpired();
    fetchProjectItems();
    _getUserRole();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> fetchProjectItems() async {
    try {
      setState(() => isLoading = true);
      final fetched = await FetchProjectItems();
      setState(() {
        projects = fetched;
        isLoading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching projects: $e");
    }
  }

  Future<void> deleteProject(int projectId) async {
    bool success = await annotationService.deleteProject(projectId);
    if (success) {
      await fetchProjectItems();
      _snack("Project deleted successfully", isError: false);
    } else {
      _snack("Failed to delete project", isError: true);
    }
  }

  void _checkIfTokenExpired() async {
    String token = await SecureStorage().readSecureData('jwtToken');
    if (token == 'No data found!' || JwtDecoder.isExpired(token)) {
      await SecureStorage().deleteToken();
      Get.offAllNamed('/home');
    }
  }

  Future<void> _getUserRole() async {
    String? role = await SecureStorage().readSecureData('role');
    setState(() => userRole = role);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: isError ? _C.danger : _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _logout(BuildContext context) async {
    await SecureStorage().deleteToken();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => HomePage()));
  }

  List<Project> get _filteredProjects {
    if (_searchQuery.isEmpty) return projects;
    return projects
        .where((p) =>
            p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.language.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ─── Overlays ─────────────────────────────────────────────────────────────

  void _showOverlay(BuildContext context) async {
    OverlayState overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) => Center(
        child: AddProjectOverlay(
          onCancel: () async {
            await fetchProjectItems();
            overlayEntry.remove();
            setState(() {});
          },
        ),
      ),
    );
    overlayState.insert(overlayEntry);
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(children: [
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ]),
      ),
    );
  }

  void _showSearchPopup(BuildContext context) {
    String? selectedMWEType;
    String? projectTitle;
    List<Map<String, dynamic>> searchResults = [];
    List<Project> projectList = [];
    bool loading = true;
    String? errorMessage;

    final mweTypes = [
      "Noun Compound",
      "Reduplicated",
      "Echo",
      "Opaque",
      "Opaque-Idiom",
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        if (loading) {
          FetchProjectItems().then((p) {
            ss(() {
              projectList = p;
              loading = false;
            });
          }).catchError((_) {
            ss(() {
              errorMessage = "Failed to load projects";
              loading = false;
            });
          });
        }

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: 560,
                maxWidth: MediaQuery.of(ctx).size.width * 0.75,
                maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _C.primaryLight,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.manage_search,
                          color: _C.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Search Multi Word Expression Type',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _C.text)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Filter annotations by MWE type across all or specific projects.',
                    style: TextStyle(fontSize: 13, color: _C.textMuted),
                  ),
                  const SizedBox(height: 24),

                  // MWE Type chips for quick selection
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mweTypes.map((type) {
                      final isSelected = selectedMWEType == type;
                      return GestureDetector(
                        onTap: () => ss(
                            () => selectedMWEType = isSelected ? null : type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? _C.primary : _C.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected ? _C.primary : _C.border),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : _C.textMuted)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Project filter dropdown
                  loading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                          ? Text(errorMessage!,
                              style: const TextStyle(color: _C.danger))
                          : _StyledDropdown<String>(
                              value: projectTitle,
                              hint: 'Filter by Project (optional)',
                              items: [
                                const DropdownMenuItem(
                                    value: 'All', child: Text('All Projects')),
                                ...projectList.map((p) => DropdownMenuItem(
                                    value: p.title, child: Text(p.title))),
                              ],
                              onChanged: (v) => ss(() => projectTitle = v),
                            ),
                  const SizedBox(height: 20),

                  // Results table
                  if (searchResults.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _C.primaryLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          '${searchResults.length} result${searchResults.length == 1 ? '' : 's'} found',
                          style: const TextStyle(
                              color: _C.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(_C.bg),
                          border: TableBorder.all(
                              color: _C.border,
                              borderRadius: BorderRadius.circular(8)),
                          columns: const [
                            DataColumn(label: Text('Word Phrase')),
                            DataColumn(label: Text('Sentence')),
                            DataColumn(label: Text('Project')),
                            DataColumn(label: Text('Sentence ID')),
                          ],
                          rows: searchResults
                              .map((r) => DataRow(cells: [
                                    DataCell(Text(r['word_phrase'] ?? '')),
                                    DataCell(Text(r['sentence_text'] ?? '',
                                        overflow: TextOverflow.ellipsis)),
                                    DataCell(Text(r['project_title'] ?? '')),
                                    DataCell(Text(r['sentence_id'].toString())),
                                  ]))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel',
                            style: TextStyle(color: _C.textMuted))),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: selectedMWEType == null
                          ? null
                          : () async {
                              try {
                                final r =
                                    await searchAnnotationsWithProjectFilter(
                                        selectedMWEType ?? "",
                                        projectTitle ?? "All");
                                ss(() => searchResults = r);
                              } catch (e) {
                                print("Search error: $e");
                              }
                            },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Search'),
                      style: FilledButton.styleFrom(
                          backgroundColor: _C.primary,
                          disabledBackgroundColor: _C.border,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showEditDialog(BuildContext context, Project project) {
    final ctrl = TextEditingController(text: project.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Project',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Project Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _C.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final t = ctrl.text.trim();
              if (t.isEmpty) {
                _snack("Title cannot be empty", isError: true);
                return;
              }
              try {
                await updateProjectTitle(project.id, t);
                setState(() => project.title = t);
                _snack("Project renamed successfully");
                Navigator.of(context).pop();
              } catch (e) {
                _snack("Failed to update: $e", isError: true);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;
    final totalPages = (filtered.length / itemsPerPage).ceil().clamp(1, 9999);
    final safeCurrentPage = currentPage.clamp(0, totalPages - 1);
    final pageProjects = filtered
        .skip(safeCurrentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          _Sidebar(
            onSearch: () => _showSearchPopup(context),
            onLogout: () => _logout(context),
            onProfile: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => ProfilePage())),
            onContact: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ContactUsPage())),
            onFeedback: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => FeedbackPage())),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                _TopBar(
                  userRole: userRole,
                  onAddProject:
                      userRole == 'Admin' ? () => _showOverlay(context) : null,
                  onSearch: (q) => setState(() {
                    _searchQuery = q;
                    currentPage = 0;
                  }),
                ),

                // Content area
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _C.primary))
                      : filtered.isEmpty
                          ? _EmptyState(
                              message: _searchQuery.isEmpty
                                  ? 'No projects yet. Create your first project!'
                                  : 'No projects match "$_searchQuery"')
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          28, 16, 28, 16),
                                      itemCount: pageProjects.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) => _ProjectCard(
                                        project: pageProjects[i],
                                        userRole: userRole,
                                        onTap: () async {
                                          await SecureStorage()
                                              .readSecureData('user_id');
                                          sentences = await FetchSentenceItems(
                                              pageProjects[i].id);
                                          await Get.to(AnnotateSentencePage(
                                            sentences: sentences,
                                            project: pageProjects[i],
                                          ));
                                          await fetchProjectItems();
                                        },
                                        onDelete: () async {
                                          final ok = await showDialog<bool>(
                                            context: ctx,
                                            builder: (_) => _ConfirmDialog(
                                              title: 'Delete Project',
                                              message:
                                                  'Are you sure you want to delete "${pageProjects[i].title}"? This cannot be undone.',
                                              confirmLabel: 'Delete',
                                              isDanger: true,
                                            ),
                                          );
                                          if (ok == true) {
                                            await deleteProject(
                                                pageProjects[i].id);
                                          }
                                        },
                                        onEdit: () => _showEditDialog(
                                            ctx, pageProjects[i]),
                                        onAssignUser: () async {
                                          try {
                                            final orgName =
                                                await SecureStorage()
                                                    .readSecureData(
                                                        'organization');
                                            final users =
                                                await fetchUsersByOrganization(
                                                    orgName);
                                            await showDialog(
                                              context: ctx,
                                              builder: (_) => _AssignUserDialog(
                                                users: users,
                                                projectId: pageProjects[i].id,
                                                onLoadingDialog: (msg) =>
                                                    _showLoadingDialog(
                                                        ctx, msg),
                                                onSnack: _snack,
                                              ),
                                            );
                                          } catch (e) {
                                            _snack('Failed to load users: $e',
                                                isError: true);
                                          }
                                        },
                                        onDownload: () async {
                                          final type = await showDialog<String>(
                                            context: ctx,
                                            builder: (_) =>
                                                const _DownloadDialog(),
                                          );
                                          if (type != null) {
                                            try {
                                              if (type == 'TXT') {
                                                await annotationService
                                                    .downloadAnnotationsTXT(
                                                        pageProjects[i].id,
                                                        pageProjects[i].title);
                                              } else {
                                                await annotationService
                                                    .downloadAnnotationsXML(
                                                        pageProjects[i].id,
                                                        pageProjects[i].title);
                                              }
                                              _snack(
                                                  '$type downloaded successfully');
                                            } catch (e) {
                                              _snack('Download failed: $e',
                                                  isError: true);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  // Pagination
                                  if (totalPages > 1)
                                    _Pagination(
                                      currentPage: safeCurrentPage,
                                      totalPages: totalPages,
                                      onPageChanged: (p) =>
                                          setState(() => currentPage = p),
                                    ),
                                  const SizedBox(height: 16),
                                ],
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
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onLogout;
  final VoidCallback onProfile;
  final VoidCallback onContact;
  final VoidCallback onFeedback;

  const _Sidebar({
    required this.onSearch,
    required this.onLogout,
    required this.onProfile,
    required this.onContact,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _C.sidebar,
      child: Column(
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _C.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_stories_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('MWE Workbench',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2)),
              ),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0xFF2A2B38), height: 1),
          ),
          const SizedBox(height: 12),

          _SidebarItem(
              icon: Icons.folder_open_outlined,
              label: 'Projects',
              isActive: true),
          _SidebarItem(
              icon: Icons.manage_search,
              label: 'Search MWE Type',
              onTap: onSearch),
          _SidebarItem(
              icon: Icons.person_outline, label: 'Profile', onTap: onProfile),

          const Spacer(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0xFF2A2B38), height: 1),
          ),
          const SizedBox(height: 8),

          _SidebarItem(
              icon: Icons.mail_outline, label: 'Contact Us', onTap: onContact),
          _SidebarItem(
              icon: Icons.feedback_outlined,
              label: 'Feedback',
              onTap: onFeedback),
          const SizedBox(height: 8),

          _SidebarItem(
              icon: Icons.logout,
              label: 'Logout',
              onTap: onLogout,
              isDanger: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isDanger;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? _C.danger
        : isActive
            ? Colors.white
            : const Color(0xFF8B8FA8);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _C.sidebarAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String? userRole;
  final VoidCallback? onAddProject;
  final ValueChanged<String> onSearch;

  const _TopBar(
      {required this.userRole,
      required this.onAddProject,
      required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        const Text('Projects',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.text,
                letterSpacing: -0.3)),
        const SizedBox(width: 24),

        // Search
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search projects…',
                hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: _C.textMuted, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _C.primary, width: 2)),
                filled: true,
                fillColor: _C.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        FilledButton.icon(
          onPressed: onAddProject,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Project',
              style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor:
                onAddProject != null ? _C.primary : Colors.grey.shade300,
            foregroundColor: onAddProject != null ? Colors.white : _C.textMuted,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ]),
    );
  }
}

// ─── Project Card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final Project project;
  final String? userRole;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAssignUser;
  final VoidCallback onDownload;

  const _ProjectCard({
    required this.project,
    required this.userRole,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onAssignUser,
    required this.onDownload,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final progress = p.total == 0 ? 0.0 : p.completed / p.total;
    final isAdmin = widget.userRole == 'Admin';

    // MWE type color mapping
    const mweColor = Color(0xFF7C5CFC);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _hovered ? _C.primary.withOpacity(0.4) : _C.border),
          boxShadow: [
            BoxShadow(
                color: _hovered ? _C.primary.withOpacity(0.08) : _C.cardShadow,
                blurRadius: _hovered ? 16 : 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _C.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories_outlined,
                      color: mweColor, size: 24),
                ),
                const SizedBox(width: 16),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _C.text)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _Chip(
                            label: p.language,
                            color: _C.primary,
                            bg: _C.primaryLight),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(p.description,
                              style: const TextStyle(
                                  fontSize: 12.5, color: _C.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    _StatBadge(
                        label: 'Sentences',
                        value: '${p.completed}/${p.total}',
                        color: _C.success),
                    const SizedBox(width: 16),
                    _StatBadge(
                        label: 'MWEs',
                        value: '${p.mweCount}',
                        color: _C.warning),
                  ]),
                ),

                // Progress
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  progress == 1.0 ? _C.success : _C.textMuted)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: _C.border,
                          valueColor: AlwaysStoppedAnimation(
                              progress == 1.0 ? _C.success : _C.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Actions
                Row(children: [
                  _ActionIcon(
                    icon: Icons.download_outlined,
                    tooltip: 'Download',
                    onTap: widget.onDownload,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: widget.onEdit,
                    ),
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.person_add_outlined,
                      tooltip: 'Assign User',
                      onTap: widget.onAssignUser,
                    ),
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete',
                      color: _C.danger,
                      bgColor: _C.dangerLight,
                      onTap: widget.onDelete,
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: _C.textMuted)),
        ],
      );
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = _C.textMuted,
    this.bgColor = _C.bg,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      );
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.primary, width: 2)),
          filled: true,
          fillColor: _C.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        hint: Text(hint,
            style: const TextStyle(color: _C.textMuted, fontSize: 14)),
        items: items,
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(12),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
                BoxDecoration(color: _C.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.auto_stories_outlined,
                size: 48, color: _C.primary),
          ),
          const SizedBox(height: 20),
          Text(message,
              style: const TextStyle(
                  fontSize: 15,
                  color: _C.textMuted,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _Pagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PageBtn(
          icon: Icons.chevron_left,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 8),
        ...List.generate(totalPages, (i) {
          final isActive = i == currentPage;
          return GestureDetector(
            onTap: () => onPageChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isActive ? _C.primary : _C.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isActive ? _C.primary : _C.border),
              ),
              alignment: Alignment.center,
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isActive ? Colors.white : _C.textMuted)),
            ),
          );
        }),
        const SizedBox(width: 8),
        _PageBtn(
          icon: Icons.chevron_right,
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ]),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border)),
          alignment: Alignment.center,
          child: Icon(icon,
              size: 18,
              color: enabled ? _C.text : _C.textMuted.withOpacity(0.4)),
        ),
      );
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDanger;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(color: _C.textMuted, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: isDanger ? _C.danger : _C.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text(confirmLabel),
          ),
        ],
      );
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Format',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _FormatTile(
              format: 'TXT',
              icon: Icons.text_snippet_outlined,
              desc: 'Plain text annotation export',
              onTap: () => Navigator.of(context).pop('TXT')),
          const SizedBox(height: 8),
          _FormatTile(
              format: 'XML',
              icon: Icons.code,
              desc: 'Structured XML annotation export',
              onTap: () => Navigator.of(context).pop('XML')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
        ],
      );
}

class _FormatTile extends StatelessWidget {
  final String format;
  final IconData icon;
  final String desc;
  final VoidCallback onTap;
  const _FormatTile(
      {required this.format,
      required this.icon,
      required this.desc,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: _C.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(format,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _C.text)),
              Text(desc,
                  style: const TextStyle(fontSize: 12, color: _C.textMuted)),
            ]),
            const Spacer(),
            const Icon(Icons.chevron_right, color: _C.textMuted),
          ]),
        ),
      );
}

class _AssignUserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final int projectId;
  final Function(String) onLoadingDialog;
  final Function(String, {bool isError}) onSnack;

  const _AssignUserDialog({
    required this.users,
    required this.projectId,
    required this.onLoadingDialog,
    required this.onSnack,
  });

  @override
  State<_AssignUserDialog> createState() => _AssignUserDialogState();
}

class _AssignUserDialogState extends State<_AssignUserDialog> {
  Set<int> selectedUserIds = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Assign Users',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: widget.users.length,
            itemBuilder: (_, i) {
              final user = widget.users[i];
              final selected = selectedUserIds.contains(user['id']);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected)
                    selectedUserIds.remove(user['id']);
                  else
                    selectedUserIds.add(user['id']);
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _C.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: selected ? _C.primary : _C.border),
                  ),
                  child: Row(children: [
                    Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? _C.primary : _C.textMuted,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(user['name'],
                        style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? _C.primary : _C.text)),
                  ]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: selectedUserIds.isEmpty
                ? null
                : () async {
                    for (int uid in selectedUserIds) {
                      final result =
                          await assignUserToProject(widget.projectId, uid);
                      if (result['statusCode'] == 409) {
                        final cont = await showDialog<bool>(
                            context: context,
                            builder: (_) => _ConfirmDialog(
                                title: 'Reassign Project',
                                message: result['data']['message'],
                                confirmLabel: 'Continue'));
                        if (cont == true) {
                          widget.onLoadingDialog("Reassigning...");
                          await assignUserToProject(widget.projectId, uid,
                              force: true);
                          Navigator.pop(context);
                          widget.onSnack('Reassigned successfully');
                        }
                      } else {
                        widget.onSnack('User assigned successfully');
                      }
                    }
                    Navigator.of(context).pop();
                  },
            style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Assign (${selectedUserIds.length})'),
          ),
        ],
      );
}
