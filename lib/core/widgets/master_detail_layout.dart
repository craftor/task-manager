import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class MasterDetailLayout extends StatefulWidget {
  final Widget masterPane;
  final Widget? detailPane;
  final double masterPaneWidth;
  final VoidCallback? onCloseDetail;

  const MasterDetailLayout({
    super.key,
    required this.masterPane,
    this.detailPane,
    this.masterPaneWidth = AppConstants.masterPaneDefaultWidth,
    this.onCloseDetail,
  });

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  late double _masterWidth;
  late double _minMaster;
  late double _maxMaster;
  bool _isResizing = false;

  static const double _dividerWidth = 8.0;

  @override
  void initState() {
    super.initState();
    _masterWidth = widget.masterPaneWidth;
    _minMaster = AppConstants.masterPaneMinWidth;
    _maxMaster = AppConstants.masterPaneMaxWidth;
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= AppConstants.sidebarBreakpoint;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _masterWidth += details.delta.dx;
      _masterWidth = _masterWidth.clamp(_minMaster, _maxMaster);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return widget.masterPane;
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            widget.onCloseDetail != null) {
          widget.onCloseDetail!();
        }
      },
      child: Row(
        children: [
          SizedBox(
            width: _masterWidth,
            child: widget.masterPane,
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _isResizing = true),
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: (_) => setState(() => _isResizing = false),
              child: Container(
                width: _dividerWidth,
                color: _isResizing
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                child: const Center(
                  child: _ResizeHandle(),
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.detailPane ?? _EmptyDetailPane(onClose: widget.onCloseDetail),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _EmptyDetailPane extends StatelessWidget {
  final VoidCallback? onClose;

  const _EmptyDetailPane({this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select an item to view details',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

