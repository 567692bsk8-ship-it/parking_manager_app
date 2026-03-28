import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'side_navigation.dart';

import '../../features/auth/providers/auth_provider.dart';

class AdminScaffold extends ConsumerWidget {
  final Widget body;
  final String selectedPath;
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget? titleTrailing;

  const AdminScaffold({
    super.key,
    required this.body,
    required this.selectedPath,
    this.title = '',
    this.actions,
    this.onBack,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isMobile = MediaQuery.of(context).size.width < 1024;
    final role = ref.watch(userRoleProvider);
    final isImpersonating =
        role == 'dev' && ref.watch(viewingAdminIdProvider) != null;

    final displayTitle = isImpersonating ? '$title (管理者代行モード)' : title;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100相当
      appBar: isMobile
          ? AppBar(
              centerTitle: false,
              titleSpacing: 0,
              leading: onBack != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: onBack,
                    )
                  : null,
              title: Container(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width *
                      0.5, // 画面の半分以上に広がらないように制限
                ),
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  displayTitle,
                  style: GoogleFonts.notoSansJp(
                    fontWeight: FontWeight.bold,
                    fontSize: 15, // 少し小さくしてボタンのスペースを確保
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              actions: actions,
            )
          : null,
      drawer: isMobile
          ? Drawer(child: SideNavigation(selectedPath: selectedPath))
          : null,
      body: Row(
        children: [
          if (!isMobile) SideNavigation(selectedPath: selectedPath),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        if (onBack != null) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                            onPressed: onBack,
                            color: const Color(0xFF64748B),
                            tooltip: '戻る',
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayTitle,
                                  style: GoogleFonts.notoSansJp(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (titleTrailing != null) ...[
                                const SizedBox(width: 8),
                                titleTrailing!,
                              ],
                            ],
                          ),
                        ),
                        if (actions != null) ...[
                          const SizedBox(width: 16),
                          Row(children: actions!),
                        ],
                      ],
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter, // ここで上揃えを指定
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(selectedPath + title),
                      child: body,
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
