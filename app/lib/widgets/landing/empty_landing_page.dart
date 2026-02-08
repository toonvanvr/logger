import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';
import 'landing_helpers.dart';

/// Full-screen landing page shown when there are no logs and no active
/// connection. Provides quick-start instructions, keyboard shortcuts, and
/// a button to open the connection settings.
class EmptyLandingPage extends StatelessWidget {
  /// Called when the user taps the "Connect to Server" button.
  final VoidCallback? onConnect;
  const EmptyLandingPage({super.key, this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(painter: LogoPainter()),
                ),
                const SizedBox(height: 12),
                Text(
                  'Logger',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: LoggerColors.fgPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time structured log viewer',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: LoggerColors.fgSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ConnectButton(onTap: onConnect),
                const SizedBox(height: 32),
                _buildQuickStart(),
                const SizedBox(height: 20),
                _buildShortcuts(),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    LinkPill(icon: Icons.menu_book, label: 'Docs'),
                    LinkPill(icon: Icons.settings, label: 'Config'),
                    LinkPill(icon: Icons.extension, label: 'Plugins'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoggerColors.bgRaised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Start', style: _sectionHeader),
          const StepRow(
            number: '1',
            title: 'Start server',
            code: 'bun run server/src/main.ts',
          ),
          const StepRow(
            number: '2',
            title: 'Install SDK',
            code: 'bun add @toon/logger',
          ),
          const StepRow(
            number: '3',
            title: 'Send logs',
            code: 'Logs appear here automatically',
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoggerColors.bgRaised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Shortcuts', style: _sectionHeader),
              const Spacer(),
              Text(
                'View All →',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              KbdChip(keys: 'Ctrl+M', label: 'mini'),
              KbdChip(keys: 'Alt+Scroll', label: 'line'),
              KbdChip(keys: 'Ctrl+←/→', label: 'pan'),
              KbdChip(keys: 'Ctrl+0', label: 'reset'),
              KbdChip(keys: 'Shift+Click', label: 'range'),
              KbdChip(keys: 'Ctrl+Scroll', label: 'zoom'),
            ],
          ),
        ],
      ),
    );
  }
}

final _sectionHeader = GoogleFonts.inter(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
  color: LoggerColors.fgPrimary,
);
