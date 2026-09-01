import 'package:flutter/material.dart';
import 'package:yoyo_ir1_tracker/domain/yoyo_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';

class ProtocolReferenceScreen extends StatelessWidget {
  const ProtocolReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: athleticBlue, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Yo-Yo IR1 Protocol', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Rules and shuttle reference', style: TextStyle(color: slate400, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        Card(
          color: slate900,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRuleBullet('Test consists of 2 × 20m shuttles per speed level.'),
                _buildRuleBullet('Athletes have a 10-second active recovery period between shuttles (walking 2 × 5m).'),
                _buildRuleBullet('A warning is given if an athlete fails to complete a shuttle in time.'),
                _buildRuleBullet('An athlete is eliminated on their second failure.'),
                _buildRuleBullet('VO₂max calculation: IR1 distance (m) × 0.0084 + 36.4'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          color: slate800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: const [
              Expanded(flex: 2, child: Text('LEVEL', style: TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('SPEED', style: TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('DISTANCE', style: TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('RUN TIME', style: TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('VO₂MAX', style: TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: YoYoProtocol.shuttles.length,
            itemBuilder: (context, index) {
              return _ProtocolRow(shuttle: YoYoProtocol.shuttles[index], isEven: index % 2 == 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•', style: TextStyle(color: athleticBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  final YoYoShuttle shuttle;
  final bool isEven;

  const _ProtocolRow({required this.shuttle, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final vo2 = YoYoProtocol.calculateVo2Max(shuttle.cumulativeDistanceMeters);
    return Container(
      color: isEven ? slate900 : slate800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(shuttle.levelDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('${shuttle.speedKmh.toStringAsFixed(1)} km/h', style: const TextStyle(color: slate400))),
          Expanded(flex: 2, child: Text('${shuttle.cumulativeDistanceMeters}m', style: const TextStyle(color: athleticBlue, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('${shuttle.runDurationSeconds.toStringAsFixed(1)}s', style: const TextStyle(color: slate400))),
          Expanded(flex: 2, child: Text(vo2.toStringAsFixed(1), style: const TextStyle(color: runGreen))),
        ],
      ),
    );
  }
}
