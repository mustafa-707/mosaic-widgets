import 'package:mosaic/dsl.dart';

MosaicDefinition buildWeather() => MosaicDefinition(
      name: 'Weather',
      width: 2,
      height: 2,
      root: MContainer(
        background: const MColor.hex('#4A90D9', dark: '#1C3D5A'),
        radius: 20,
        child: MPadding(
          const MInsets.all(14),
          MColumn(
            crossAxisAlignment: MCrossAxisAlignment.start,
            [
              // City name
              const MText(
                'San Francisco',
                style: MTextStyle(
                  color: MColor.hex('#FFFFFF'),
                  bold: true,
                  size: 14,
                ),
              ),
              const MSpacer(),
              // Condition icon
              const MIcon(
                sfSymbol: 'cloud.sun.fill',
                androidDrawable: 'ic_weather',
                size: 32,
                color: MColor.hex('#FFD700'),
              ),
              const MSpacer(),
              // Current temperature (live data)
              MText(
                MBind('temp'),
                style: const MTextStyle(
                  color: MColor.hex('#FFFFFF'),
                  bold: true,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
