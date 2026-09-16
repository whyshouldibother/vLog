import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'vehicle_form_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to vLog',
      subtitle: 'Your personal vehicle maintenance companion',
      icon: Icons.directions_car_rounded,
      description: 'Track fuel consumption, service history, costs, and reminders — all in one beautiful app.',
      features: [
        'Smart fuel economy calculations',
        'Service & repair tracking',
        'Maintenance reminders',
        'Cost analysis & insights',
      ],
    ),
    OnboardingPage(
      title: 'Add Your Vehicle',
      subtitle: 'Start by adding your first vehicle',
      icon: Icons.add_circle_outline_rounded,
      description: 'Enter basic details like make, model, year, and current odometer. We\'ll handle the rest.',
      features: [
        'Multiple vehicles supported',
        'Custom nicknames & photos',
        'Odometer auto-updates',
        'Fuel type & preferences',
      ],
    ),
    OnboardingPage(
      title: 'Log Fuel & Services',
      subtitle: 'Every fill-up, every service',
      icon: Icons.local_gas_station_rounded,
      description: 'Quick entry with autocomplete for stations & fuel types. Automatic cost calculations & economy tracking.',
      features: [
        'Auto-calculate total/unit price',
        'Station & fuel type memory',
        'Distance-based economy',
        'Service cost tracking',
      ],
    ),
    OnboardingPage(
      title: 'Smart Reminders',
      subtitle: 'Never miss maintenance again',
      icon: Icons.notifications_active_rounded,
      description: 'Set reminders by date, distance, or both. Get notified when service is due.',
      features: [
        'Time & distance based',
        'Recurring reminders',
        'Custom categories',
        'Push notifications',
      ],
    ),
    OnboardingPage(
      title: 'Insights & Analytics',
      subtitle: 'Visualize your vehicle\'s health',
      icon: Icons.analytics_rounded,
      description: 'Beautiful charts for fuel economy, costs, consumption trends, and vehicle comparisons.',
      features: [
        'Interactive charts',
        'Vehicle comparisons',
        'Cost breakdowns',
        'Export data (JSON)',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(completeOnboardingProvider.future);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPageView(
                    page: page,
                    isActive: index == _currentPage,
                  );
                },
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? context.cs.primary
                      : context.cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Back'),
                  ),
                )
              else
                const SizedBox(),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                flex: _currentPage > 0 ? 1 : 2,
                child: FilledButton(
                  onPressed: _currentPage == _pages.length - 1
                      ? _completeOnboarding
                      : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final String description;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.description,
    required this.features,
  });
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.page,
    required this.isActive,
  });
  final OnboardingPage page;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.cs.primaryContainer, context.cs.tertiaryContainer],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(page.icon, size: 70, color: context.cs.primary),
          ).animate(target: isActive ? 1 : 0)
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 600.ms)
            .then()
            .shimmer(duration: 1500.ms),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: context.tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ).animate(target: isActive ? 1 : 0)
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            style: context.tt.titleMedium?.copyWith(
              color: context.cs.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ).animate(target: isActive ? 1 : 0)
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 24),
          Text(
            page.description,
            style: context.tt.bodyLarge?.copyWith(
              color: context.cs.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate(target: isActive ? 1 : 0)
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),
          Column(
            children: page.features.asMap().entries.map((entry) {
              final index = entry.key;
              final feature = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.cs.primary, context.cs.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: context.tt.bodyMedium?.copyWith(
                          color: context.cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ).animate(target: isActive ? 1 : 0)
                  .fadeIn(duration: 400.ms, delay: (500 + index * 100).ms)
                  .slideX(begin: -0.3, duration: 400.ms, curve: Curves.easeOutCubic),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}