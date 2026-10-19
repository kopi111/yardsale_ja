import 'package:flutter/material.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';

/// The three things the house does, shown once when a member first registers.
///
/// It is the first screen a new member sees after the welcome, so it is set in
/// the same hand: numbered saleroom notes on the paper canvas, not a carousel
/// of coloured circles.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _notes = [
    _Note(
      index: '01',
      label: 'THE FLOOR',
      title: 'Bid on lots from every parish.',
      body: 'Every open lot on the island sits on one floor. Raise your '
          'paddle, and the house keeps you posted when you are outbid.',
    ),
    _Note(
      index: '02',
      label: 'CONSIGN',
      title: 'Put your own lot up.',
      body: 'Photograph it, set the opening price, choose how long it runs. '
          'Bidders come to you.',
    ),
    _Note(
      index: '03',
      label: 'SETTLE',
      title: 'Agree the handover.',
      body: 'Message the seller before the hammer falls, pay them directly, '
          'and record the settlement so you both hold the same account of it.',
    ),
  ];

  void _goToHome() {
    // The reactive gate in app.dart already shows HomeScreen once the user is
    // logged in. Pop the welcome/profile/onboarding stack to reveal it instead
    // of pushing a second HomeScreen (which caused a duplicate, thrashing load).
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _advance() {
    if (_currentPage == _notes.length - 1) {
      _goToHome();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLast = _currentPage == _notes.length - 1;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToHome,
                child: Text('SKIP', style: AppTheme.sectionLabel(palette.muted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _notes.length,
                itemBuilder: (_, i) => _notes[i],
              ),
            ),
            _Rule(current: _currentPage, total: _notes.length),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _advance,
                child: Text(isLast ? 'ENTER THE SALEROOM' : 'NEXT'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/// One numbered note, set the way the welcome screen sets its three.
class _Note extends StatelessWidget {
  final String index;
  final String label;
  final String title;
  final String body;

  const _Note({
    required this.index,
    required this.label,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(index, style: AppTheme.money(52, palette.gold)),
          const SizedBox(height: 10),
          Text(label, style: AppTheme.sectionLabel(palette.gold)),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 14),
          Container(width: 54, height: 2, color: palette.hairline),
          const SizedBox(height: 14),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

/// How far through the notes the member is, ruled rather than dotted.
class _Rule extends StatelessWidget {
  final int current;
  final int total;

  const _Rule({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: i <= current ? palette.gold : palette.hairline,
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
