import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(hasCompletedOnboardingProvider);

    return onboardingAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (hasCompleted) {
        if (!hasCompleted) {
          return const OnboardingScreen();
        }

        final vehicles = ref.watch(vehiclesNotifierProvider);
        final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;

        return _HomeContent(vehicles: vehicles, settings: settings);
      },
    );
  }
}

class _HomeContent extends ConsumerStatefulWidget {
  const _HomeContent({
    required this.vehicles,
    required this.settings,
  });
  final AsyncValue<List<Vehicle>> vehicles;
  final AppSettings? settings;

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> with TickerProviderStateMixin {
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton.extended(
          heroTag: 'add_vehicle',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('Add Vehicle'),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.5, curve: Curves.easeOutCubic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          widget.vehicles.when(
            loading: () => _buildLoadingState(),
            error: (error, _) => SliverFillRemaining(
              child: ErrorView(
                message: 'Could not load vehicles: $error',
                onRetry: () => ref.invalidate(vehiclesNotifierProvider),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return _buildEmptyState();
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vehicle = list[index];
                    return _AnimatedVehicleCard(
                      vehicle: vehicle,
                      odometerLabel: widget.settings == null
                          ? null
                          : formatDistance(vehicle.currentOdometer, widget.settings!.distanceUnit),
                      index: index,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      snap: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: context.cs.surface,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildAppBarBackground(context),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'vLog',
          style: context.tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: context.cs.onSurface,
          ),
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.dashboard_outlined, size: 26),
          tooltip: 'Dashboard',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          ),
        ).animate().fadeIn(delay: 300.ms).scale(),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 26),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ).animate().fadeIn(delay: 400.ms).scale(),
      ],
    );
  }

  Widget _buildAppBarBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cs.primaryContainer.withValues(alpha: 0.3),
            context.cs.secondaryContainer.withValues(alpha: 0.2),
            context.cs.tertiaryContainer.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.cs.primary.withValues(alpha: 0.15),
                    context.cs.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.cs.tertiary.withValues(alpha: 0.12),
                    context.cs.tertiary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.cs.primary, context.cs.tertiary],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
            const SizedBox(height: 24),
            Text(
              'Loading your vehicles...',
              style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant),
            ).animate().fadeIn().shimmer(duration: 1500.ms),
          ],
        ),
      ),
    );
  }

  SliverFillRemaining _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 70,
                  color: context.cs.primary,
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut).then().shimmer(),
              const SizedBox(height: 32),
              Text(
                'No Vehicles Yet',
                style: context.tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),
              Text(
                'Add your first vehicle to start tracking fuel, service, and costs.',
                textAlign: TextAlign.center,
                style: context.tt.bodyLarge?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Your First Vehicle'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ).animate().fadeIn(delay: 400.ms).scale(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedVehicleCard extends StatefulWidget {
  const _AnimatedVehicleCard({
    required this.vehicle,
    required this.odometerLabel,
    required this.index,
  });
  final Vehicle vehicle;
  final String? odometerLabel;
  final int index;

  @override
  State<_AnimatedVehicleCard> createState() => _AnimatedVehicleCardState();
}

class _AnimatedVehicleCardState extends State<_AnimatedVehicleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _rotation = Tween<double>(begin: 0.0, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    _navigateToDetail();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _navigateToDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: widget.vehicle.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColors = [
      [context.cs.primaryContainer, context.cs.primary],
      [context.cs.secondaryContainer, context.cs.secondary],
      [context.cs.tertiaryContainer, context.cs.tertiary],
      [context.cs.errorContainer, context.cs.error],
    ];
    final colorPair = cardColors[widget.index % cardColors.length];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(
            angle: _rotation.value * (widget.index.isEven ? 1 : -1),
            child: child!,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorPair[0].withValues(alpha: 0.4),
                colorPair[0].withValues(alpha: 0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorPair[1].withValues(alpha: _isPressed ? 0.2 : 0.1),
                blurRadius: _isPressed ? 8 : 20,
                offset: Offset(0, _isPressed ? 2 : 10),
                spreadRadius: _isPressed ? 0 : -5,
              ),
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -5,
                ),
            ],
            border: Border.all(
              color: colorPair[1].withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _navigateToDetail,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Hero(
                      tag: 'vehicle_${widget.vehicle.id}',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorPair[1], colorPair[1].withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: colorPair[1].withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle.displayName,
                            style: context.tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (widget.vehicle.registrationNumber.trim().isNotEmpty) ...[
                                Icon(
                                  Icons.confirmation_number_rounded,
                                  size: 14,
                                  color: context.cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.vehicle.registrationNumber.trim(),
                                  style: context.tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: context.cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (widget.vehicle.year != null) ...[
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: context.cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.vehicle.year}',
                                  style: context.tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: context.cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (widget.odometerLabel != null) ...[
                                Icon(
                                  Icons.straighten_rounded,
                                  size: 14,
                                  color: colorPair[1],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.odometerLabel!,
                                  style: context.tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorPair[1],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: context.cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ).animate().fadeIn(delay: (200 + widget.index * 50).ms).slideX(begin: 0.3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}