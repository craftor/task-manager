import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/task.dart';
import '../presentation/providers/gantt_provider.dart';

class GanttChart extends StatelessWidget {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;
  final GanttZoom zoom;

  const GanttChart({
    super.key,
    required this.tasks,
    required this.startDate,
    required this.endDate,
    this.zoom = GanttZoom.month,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GanttChartPainter(
        tasks: tasks,
        startDate: startDate,
        endDate: endDate,
      ),
      size: Size.infinite,
    );
  }
}

class GanttChartPainter extends CustomPainter {
  final List<Task> tasks;
  final DateTime startDate;
  final DateTime endDate;

  GanttChartPainter({
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final taskHeight = 32.0;
    final rowHeight = 48.0;
    final leftPadding = 120.0;
    final totalDays = endDate.difference(startDate).inDays.clamp(1, 365);
    final dayWidth = (size.width - leftPadding) / totalDays;

    final todayX = leftPadding + DateTime.now().difference(startDate).inDays * dayWidth;

    // Draw today line (red dashed)
    final todayPaint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 2;
    todayPaint.style = PaintingStyle.stroke;

    // Draw dashed line
    const dashHeight = 5.0;
    const dashSpace = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(todayX, y),
        Offset(todayX, (y + dashHeight).clamp(0, size.height)),
        todayPaint,
      );
      y += dashHeight + dashSpace;
    }

    // Draw task bars
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final taskStart = task.startDate ?? task.createdAt;
      final taskEnd = task.dueDate ?? task.createdAt.add(const Duration(days: 1));

      final startDays = taskStart.difference(startDate).inDays.clamp(0, totalDays);
      final endDays = taskEnd.difference(startDate).inDays.clamp(0, totalDays);
      final duration = (endDays - startDays).clamp(1, totalDays);

      final barX = leftPadding + startDays * dayWidth;
      final barY = i * rowHeight + (rowHeight - taskHeight) / 2;
      final barWidth = duration * dayWidth;

      final color = _getPriorityColor(task.priority);

      // Draw bar background
      final barPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, taskHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, barPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(barRect, borderPaint);

      // Draw task title inside bar
      final textPainter = TextPainter(
        text: TextSpan(
          text: task.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: (barWidth - 8).clamp(1, barWidth - 8));
      textPainter.paint(canvas, Offset(barX + 4, barY + (taskHeight - textPainter.height) / 2));
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.low:
        return AppColors.secondary;
      case Priority.medium:
        return AppColors.warning;
      case Priority.high:
        return Colors.orange;
      case Priority.urgent:
        return AppColors.error;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}