import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedCategoryIndex = 0;
  int _selectedDateIndex = 3; // Tuesday 14th (current day)

  final List<String> _categories = [
    'Fine Motor',
    'Gross Motor',
    'Cognitive',
    'Language',
    'Social',
  ];

  final List<Map<String, dynamic>> _dates = [
    {'day': 'Sun', 'date': '12'},
    {'day': 'Mon', 'date': '13'},
    {'day': 'Tue', 'date': '14'},
    {'day': 'Wed', 'date': '15'},
    {'day': 'Thu', 'date': '16'},
    {'day': 'Fri', 'date': '17'},
    {'day': 'Sat', 'date': '18'},
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Scaffold(
      backgroundColor: scheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.accent.withValues(alpha: scheme.isDark ? 0.16 : 0.20),
              scheme.surfaceElevated,
              scheme.background,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Error banner
              Consumer(
                builder: (context, ref, _) {
                  final error = ref.watch(
                      dashboardNotifierProvider.select((s) => s.error));
                  if (error == null) return const SizedBox.shrink();
                  return MaterialBanner(
                    content: Text(error),
                    actions: [
                      TextButton(
                        onPressed: () => ref
                            .read(dashboardNotifierProvider.notifier)
                            .clearError(),
                        child: const Text('Dismiss'),
                      ),
                    ],
                    backgroundColor: AppColors.error.withValues(alpha: 0.08),
                    dividerColor: Colors.transparent,
                  );
                },
              ),

              // Top Header Section
              _buildHeader(),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Calendar/Date Selector
                      _buildDateSelector(),

                      const SizedBox(height: 24),

                      // Activity Summary Cards
                      _buildSummaryCards(),

                      const SizedBox(height: 24),

                      // Activity Categories
                      _buildCategorySelector(),

                      const SizedBox(height: 24),

                      // Featured Activity Card
                      _buildFeaturedActivity(),

                      const SizedBox(height: 24),

                      // Upcoming Activities
                      _buildUpcomingActivities(),

                      const SizedBox(height: 100), // Space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top Row with Profile and Actions
          Row(
            children: [
              // Profile Picture
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.child_care,
                  color: scheme.onPrimary,
                  size: 28,
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  _buildActionButton(Icons.notifications_outlined,
                      hasNotification: true),
                  const SizedBox(width: 12),
                  _buildActionButton(Icons.bookmark_outline),
                  const SizedBox(width: 12),
                  _buildActionButton(Icons.calendar_today_outlined),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search Bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: scheme.surface.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.textPrimary.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: scheme.surface.withOpacity(0.8),
                  blurRadius: 15,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: scheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Search activities...',
                    style: TextStyle(
                      color: scheme.textSecondary,
                      fontSize: 16,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, {bool hasNotification = false}) {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.surface.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.textPrimary.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: scheme.primary,
            size: 20,
          ),
        ),
        if (hasNotification)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDateIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDateIndex = index;
              });
            },
            child: Container(
              width: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dates[index]['day'],
                    style: TextStyle(
                      color: isSelected ? scheme.onPrimary : scheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dates[index]['date'],
                    style: TextStyle(
                      color: isSelected ? scheme.onPrimary : scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.touch_app,
            value: '12',
            label: 'Activities',
            // Three distinct hues distinguishing the three stat cards from
            // each other — not semantic tokens (these aren't warnings/
            // errors), so pulled from the palette's own primary/secondary/
            // accent trio rather than AppColors.warning etc.
            color: scheme.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.psychology,
            value: '06',
            label: 'Skills',
            color: scheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.schedule,
            value: '2:30',
            label: 'Hours',
            color: scheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.surface.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.textPrimary.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: scheme.surface.withOpacity(0.8),
            blurRadius: 15,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Icon(
                Icons.more_vert,
                color: scheme.textSecondary,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.textSecondary,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.surface.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.textPrimary.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(_categories[index]),
                    color: isSelected ? scheme.onPrimary : scheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected ? scheme.onPrimary : scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Fine Motor':
        return Icons.touch_app;
      case 'Gross Motor':
        return Icons.directions_run;
      case 'Cognitive':
        return Icons.psychology;
      case 'Language':
        return Icons.chat;
      case 'Social':
        return Icons.people;
      default:
        return Icons.star;
    }
  }

  Widget _buildFeaturedActivity() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.textPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.accent],
              ),
            ),
          ),

          // Overlay Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: scheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Beginner',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro Text',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bookmark_outline,
                        color: scheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Bottom Content
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fine Motor Skills',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: scheme.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '10 Minutes',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'SF Pro Text',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.local_fire_department,
                                color: scheme.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '200 Points',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'SF Pro Text',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: scheme.onPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.textPrimary.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: scheme.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingActivities() {
    final scheme = ref.watch(activeColorSchemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Activities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
            fontFamily: 'SF Pro Display',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.surface.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.textPrimary.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: scheme.surface.withOpacity(0.8),
                      blurRadius: 15,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: scheme.primary,
                            size: 16,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.more_vert,
                          color: scheme.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cognitive Skills',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Memory games and puzzles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.textSecondary,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: scheme.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '15 min',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.textSecondary,
                            fontFamily: 'SF Pro Text',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Bottom nav removed — this screen is now a tab inside AppShell
  // (lib/core/router/app_shell.dart), which renders the one persistent
  // Home/Search/Progress/Profile bar. See FT-003.
}
