import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/domain/test_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

class ProtocolReferenceScreen extends StatefulWidget {
  const ProtocolReferenceScreen({super.key});

  @override
  State<ProtocolReferenceScreen> createState() =>
      _ProtocolReferenceScreenState();
}

class _ProtocolReferenceScreenState extends State<ProtocolReferenceScreen> {
  TestType? _selectedTypeOverride;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final activeTestType =
        _selectedTypeOverride ?? viewModel.state.selectedTestType;
    final protocol = activeTestType.protocol;
    final isYoYo = activeTestType == TestType.yoyoIR1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: athleticBlue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activeTestType.displayName} Protocol',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      activeTestType.fullName,
                      style: const TextStyle(color: slate400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Protocol Switcher Segmented Button
              SegmentedButton<TestType>(
                segments: const [
                  ButtonSegment<TestType>(
                    value: TestType.yoyoIR1,
                    label: Text('Yo-Yo', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<TestType>(
                    value: TestType.beepTest,
                    label: Text('Beep', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {activeTestType},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedTypeOverride = set.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return athleticBlue.withValues(alpha: 0.25);
                    }
                    return slate800;
                  }),
                ),
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
              children: isYoYo
                  ? [
                      _buildRuleBullet(
                        'Test consists of 2 × 20m shuttles per speed level.',
                      ),
                      _buildRuleBullet(
                        'Athletes have a 10-second active recovery period between shuttles (walking 2 × 5m).',
                      ),
                      _buildRuleBullet(
                        'A warning is given if an athlete fails to complete a shuttle in time.',
                      ),
                      _buildRuleBullet(
                        'An athlete is eliminated on their second failure.',
                      ),
                      _buildRuleBullet(
                        'VO₂max calculation: IR1 distance (m) × 0.0084 + 36.4',
                      ),
                    ]
                  : [
                      _buildRuleBullet(
                        'Test consists of continuous 20m shuttle runs across 21 speed levels.',
                      ),
                      _buildRuleBullet(
                        'No recovery period between shuttles; shuttle pace speeds up each level.',
                      ),
                      _buildRuleBullet(
                        'A warning is given if an athlete fails to reach the line before the audio beep.',
                      ),
                      _buildRuleBullet(
                        'An athlete is eliminated on their second consecutive failure.',
                      ),
                      _buildRuleBullet(
                        'VO₂max calculation: Speed (km/h) × 3.1 + 3.5',
                      ),
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
              Expanded(
                flex: 2,
                child: Text(
                  'LEVEL',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SPEED',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'DISTANCE',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'RUN TIME',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'VO₂MAX',
                  style: TextStyle(
                    color: slate400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: protocol.shuttles.length,
            itemBuilder: (context, index) {
              return _ProtocolRow(
                shuttle: protocol.shuttles[index],
                protocol: protocol,
                isEven: index % 2 == 0,
              );
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
          const Text(
            '•',
            style: TextStyle(
              color: athleticBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  final TestShuttle shuttle;
  final TestProtocol protocol;
  final bool isEven;

  const _ProtocolRow({
    required this.shuttle,
    required this.protocol,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final vo2 = protocol.calculateVo2Max(
      shuttle.cumulativeDistanceMeters,
      speedKmh: shuttle.speedKmh,
    );
    return Container(
      color: isEven ? slate900 : slate800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              shuttle.levelDisplay,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${shuttle.speedKmh.toStringAsFixed(1)} km/h',
              style: const TextStyle(color: slate400),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${shuttle.cumulativeDistanceMeters}m',
              style: const TextStyle(
                color: athleticBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${shuttle.runDurationSeconds.toStringAsFixed(1)}s',
              style: const TextStyle(color: slate400),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              vo2.toStringAsFixed(1),
              style: const TextStyle(color: runGreen),
            ),
          ),
        ],
      ),
    );
  }
}
