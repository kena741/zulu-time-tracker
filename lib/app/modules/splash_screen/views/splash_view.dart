import 'package:flutter/material.dart';

import '../../../utils/nav_helper.dart';

/// Uses post-frame navigation so we never depend on GetX [onReady] / lazyPut timing
/// (a common cause of an infinite splash spinner on desktop).
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scheduled || !mounted) return;
      _scheduled = true;
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        NavHelper.routeFromSplash();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: ColoredBox(
        color: cs.surface,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 360,
                    maxHeight: 360,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Image.asset(
                      'assets/images/splash.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.timer_outlined,
                          size: 72,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
