import 'package:flutter/material.dart';

class GlassHeaderAction {
  const GlassHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

class GlassPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.actions = const <GlassHeaderAction>[],
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<GlassHeaderAction> actions;

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      toolbarHeight: preferredSize.height,
      backgroundColor: const Color(0xFF041B4A),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.07),
              const Color(0xFF173A78).withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFF7DE77).withValues(alpha: 0.07),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF7DE77).withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFF7DE77),
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: subtitle == null || subtitle!.trim().isEmpty
                  ? Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
            ),
            for (final action in actions)
              IconButton(
                tooltip: action.tooltip,
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
