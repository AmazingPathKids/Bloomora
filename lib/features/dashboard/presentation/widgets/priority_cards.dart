import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../assessment/presentation/providers/priority_selection_provider.dart';

class PriorityCards extends ConsumerWidget {
  const PriorityCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorities = ref.watch(prioritySelectionNotifierProvider).priorities;
    
    if (priorities.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Top 3 Priorities',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: priorities.length,
            itemBuilder: (context, index) {
              final priority = priorities[index];
              final domainColor = _getDomainColor(priority);
              final icon = _getDomainIcon(priority);
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: domainColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: domainColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: domainColor,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        priority,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: domainColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getDomainColor(String domain) {
    switch (domain) {
      case 'Fine Motor Skills':
        return AppColors.domainFineMotor;
      case 'Gross Motor Skills':
        return AppColors.domainGrossMotor;
      case 'Communication':
        return AppColors.domainCommunication;
      case 'Social-Emotional':
        return AppColors.domainSocialEmotional;
      case 'Cognitive':
        return AppColors.domainCognitive;
      case 'Adaptive Skills':
        return AppColors.domainAdaptive;
      case 'Sensory Processing':
        return AppColors.domainSensory;
      default:
        return AppColors.primary;
    }
  }

  IconData _getDomainIcon(String domain) {
    switch (domain) {
      case 'Fine Motor Skills':
        return Icons.touch_app;
      case 'Gross Motor Skills':
        return Icons.directions_run;
      case 'Communication':
        return Icons.chat_bubble_outline;
      case 'Social-Emotional':
        return Icons.people_outline;
      case 'Cognitive':
        return Icons.psychology;
      case 'Adaptive Skills':
        return Icons.self_improvement;
      case 'Sensory Processing':
        return Icons.hearing;
      default:
        return Icons.help_outline;
    }
  }
}
