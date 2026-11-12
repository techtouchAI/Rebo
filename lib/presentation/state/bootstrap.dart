import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/asset_content_repository.dart';
import '../../data/local/prefs_progress_repository.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../app.dart';
import 'app_state.dart';

/// Loads the offline content and the saved reading state, then starts the app.
///
/// The loader is injectable so that widget tests can run the full application
/// against the very same JSON assets.
class MirsamBootstrap extends StatefulWidget {
  const MirsamBootstrap({
    super.key,
    this.contentRepository,
    this.progressRepository,
  });

  final ContentRepository? contentRepository;
  final ProgressRepository? progressRepository;

  @override
  State<MirsamBootstrap> createState() => _MirsamBootstrapState();
}

class _MirsamBootstrapState extends State<MirsamBootstrap> {
  late Future<_BootstrapData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BootstrapData> _load() async {
    final contentRepository = widget.contentRepository ?? const AssetContentRepository();
    final progressRepository = widget.progressRepository ?? const PrefsProgressRepository();
    final results = await Future.wait<Object>(<Future<Object>>[
      contentRepository.load(),
      progressRepository.load(),
    ]);
    final library = results[0] as Library;
    return _BootstrapData(
      state: AppState(
        library: library,
        progress: results[1] as ReadingProgress,
        progressRepository: progressRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_BootstrapData> snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: _StartupErrorScreen(message: '${snapshot.error}'),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return MaterialApp(
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            home: const _SplashScreen(),
          );
        }
        return AppScope(
          state: data.state,
          child: const MirsamApp(),
        );
      },
    );
  }
}

class _BootstrapData {
  const _BootstrapData({required this.state});

  final AppState state;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.clay),
            ),
            SizedBox(height: 18),
            Text(
              'مِرسم',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48, color: AppColors.clay),
              const SizedBox(height: 16),
              const Text('تعذّر تحميل محتوى التطبيق', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
