import 'package:mosaic/dsl.dart';

/// A delivery-tracking Live Activity: lock-screen banner + Dynamic Island.
/// The app drives it via MosaicLiveActivities.start/update/end with a
/// {status, progress, eta} data map.
MosaicLiveActivity buildOrderTracker() {
  return MosaicLiveActivity(
    name: 'OrderTracker',
    lockScreen: MContainer(
      background: const MColor.hex('#111827', dark: '#000000'),
      radius: 16,
      child: MPadding(
        const MInsets.all(12),
        MColumn(
          crossAxisAlignment: MCrossAxisAlignment.start,
          [
            const MText(
              'Order on the way',
              style: MTextStyle(color: MColor.hex('#FFFFFF'), size: 14, bold: true),
            ),
            MText(
              MBind('status'),
              style: const MTextStyle(color: MColor.hex('#9CA3AF'), size: 12),
            ),
            MProgressBar(
              value: MBind('progress'),
              color: const MColor.hex('#34D399'),
            ),
            MRow([
              const MText(
                'ETA ',
                style: MTextStyle(color: MColor.hex('#9CA3AF'), size: 12),
              ),
              MText(
                MBind('eta'),
                style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true),
              ),
            ]),
          ],
        ),
      ),
    ),
    dynamicIsland: MDynamicIsland(
      compactLeading: const MText('🛵', style: MTextStyle(size: 14)),
      compactTrailing: MText(
        MBind('eta'),
        style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true),
      ),
      minimal: const MText('🛵', style: MTextStyle(size: 12)),
      expanded: MExpanded(
        leading: const MText(
          'Order',
          style: MTextStyle(color: MColor.hex('#FFFFFF'), size: 12, bold: true),
        ),
        trailing: MText(
          MBind('eta'),
          style: const MTextStyle(color: MColor.hex('#34D399'), size: 12, bold: true),
        ),
        center: MText(
          MBind('status'),
          style: const MTextStyle(color: MColor.hex('#FFFFFF'), size: 12),
        ),
        bottom: MProgressBar(
          value: MBind('progress'),
          color: const MColor.hex('#34D399'),
        ),
      ),
    ),
  );
}
