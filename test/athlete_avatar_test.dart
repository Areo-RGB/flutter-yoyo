import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyo_ir1_tracker/ui/core/athlete_avatar.dart';

void main() {
  test('maps roster first names to their optimized avatar assets', () {
    expect(athleteAvatarAssetPath('Lion'), 'assets/avatars/Lion_Macak.png');
    expect(
      athleteAvatarAssetPath('Arturo Montes Hernandez'),
      'assets/avatars/Arturo_Montes_Hernandez.png',
    );
    expect(athleteAvatarAssetPath('Unknown Moore'), isNull);
    expect(athleteAvatarAssetPath('Alex'), 'assets/avatars/Alex_Moore.png');
  });

  testWidgets('renders a mapped portrait instead of initials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AthleteAvatar(
            name: 'Lion',
            radius: 20,
            backgroundColor: Colors.blue,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/avatars/Lion_Macak.png',
    );
    expect(find.text('L'), findsNothing);
  });

  testWidgets('falls back to initials when no portrait is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AthleteAvatar(
            name: 'Zoe',
            radius: 20,
            backgroundColor: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.text('Z'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
