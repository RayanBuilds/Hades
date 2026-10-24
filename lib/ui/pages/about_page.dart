import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../widgets/common.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showHadesSnack(context, 'Could not open the link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = hadesRadius(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About Hades')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          const Center(child: AppLogo(size: 76)),
          const SizedBox(height: 16),
          const Center(child: Wordmark(fontSize: 30)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '$appTagline\nVersion $appVersion',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CREATED BY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFFF6B2C),
                      child: Text(
                        'I',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatorName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'github.com/ItzFallenMe',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open GitHub profile',
                      onPressed: () => _open(context, creatorUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Built on the shoulders of giants',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _CreditTile(
            name: 'SimpMusic',
            description:
                'The InnerTube streaming approach and feature set that inspired Hades.',
            onTap: () => _open(context, simpmusicUrl),
          ),
          _CreditTile(
            name: 'namida',
            description:
                'The deep, artwork-driven customization and player layouts that shaped the interface.',
            onTap: () => _open(context, namidaUrl),
          ),
          _CreditTile(
            name: 'LRCLIB',
            description: 'Free, open synced and plain lyrics.',
            onTap: () => _open(context, lrclibUrl),
          ),
          _CreditTile(
            name: 'YouTube Music',
            description:
                'Catalogue, artwork, and audio streams. Hades is an unofficial client.',
            onTap: () => _open(context, 'https://music.youtube.com'),
          ),
          const SizedBox(height: 22),
          Text(
            'The fine print',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hades is an unofficial, open-source client for personal use. It is '
            'not affiliated with YouTube, Google, SimpMusic, or namida. It does '
            'not host or distribute media; playback and artwork come from '
            "YouTube's public web endpoints. Hades does not bypass paid "
            'features or monetize anything.\n\n'
            'Please support the artists and creators you listen to by using '
            'YouTube Premium or buying their music. You are responsible for '
            'using this app in line with the laws and terms of service where '
            'you live.\n\n'
            'The Hades code is written for this project by $creatorName and '
            'contributors. SimpMusic and namida are separate GPL projects; '
            'their names are credited for inspiration only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _open(context, repoUrl),
            icon: const Icon(Icons.code_rounded),
            label: const Text('View source on GitHub'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: appName,
              applicationVersion: appVersion,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: AppLogo(size: 54),
              ),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
          ),
        ],
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  final String name;
  final String description;
  final VoidCallback onTap;

  const _CreditTile({
    required this.name,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
