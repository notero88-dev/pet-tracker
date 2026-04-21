import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/position.dart';

/// Widget to display position history timeline
class PositionHistoryViewer extends StatefulWidget {
  final List<Position> positions;
  final Position? selectedPosition;
  final Function(Position) onPositionSelected;
  final VoidCallback onClose;

  const PositionHistoryViewer({
    super.key,
    required this.positions,
    this.selectedPosition,
    required this.onPositionSelected,
    required this.onClose,
  });

  @override
  State<PositionHistoryViewer> createState() => _PositionHistoryViewerState();
}

class _PositionHistoryViewerState extends State<PositionHistoryViewer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.positions.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Historial de Ubicaciones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.positions.length} registros',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Timeline
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.positions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final position = widget.positions[index];
                final isSelected = widget.selectedPosition?.id == position.id;

                return _buildPositionCard(position, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(Position position, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onPositionSelected(position),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D6A4F).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D6A4F) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Timeline dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2D6A4F) : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Time
            SizedBox(
              width: 50,
              child: Text(
                DateFormat('HH:mm').format(position.deviceTime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF2D6A4F) : Colors.black,
                ),
              ),
            ),

            // Location info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position.address ?? position.coordinatesText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (position.speed != null) ...[
                        Icon(Icons.speed, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          position.speedText,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (position.batteryLevel != null) ...[
                        Icon(Icons.battery_std, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${position.batteryLevel}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Accuracy indicator
            if (position.accuracy != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getAccuracyColor(position.accuracy!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '±${position.accuracy!.toStringAsFixed(0)}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: _getAccuracyColor(position.accuracy!),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No hay historial disponible',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            label: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 10) return Colors.green;
    if (accuracy <= 50) return Colors.orange;
    return Colors.red;
  }
}
