import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/models/question_model.dart';

class TabQuestionCard extends ConsumerWidget {
  final QuestionModel question;
  final int questionNumber;
  final int? selectedScore;
  final ValueChanged<int> onScoreSelected;

  const TabQuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.onScoreSelected,
    this.selectedScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ref.watch(activeColorSchemeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: scheme.isDark ? AppShadows.darkElevationBorder() : null,
        boxShadow: AppShadows.elevation1(scheme.isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Question number badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$questionNumber',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Question text
            Expanded(
              child: Text(
                question.questionText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: scheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 0 / 1 / 2 score buttons in a row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [0, 1, 2].map((score) {
                final isSelected = selectedScore == score;
                return GestureDetector(
                  onTap: () => onScoreSelected(score),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(left: 6),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.primary : scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? scheme.primary : scheme.border,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? scheme.onPrimary : scheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
