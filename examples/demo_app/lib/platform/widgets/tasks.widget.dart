import 'package:mosaic_widgets/dsl.dart';

/// A task list — the case a widget framework has to handle and the one
/// `MListView` exists for.
///
/// The app pushes a list of maps with `MosaicBridge.saveList`; each map's keys
/// are bound per row by the item template. Android backs this with a real
/// `RemoteViewsService`, so the list scrolls without the app running.
MosaicDefinition buildTasks() => MosaicDefinition(
  name: 'Tasks',
  width: 4,
  height: 2,
  updateInterval: const Duration(minutes: 30),
  root: MContainer(
    background: const MColor.hex('#0F172A', dark: '#0B1120'),
    radius: 24,
    border: const MBorder(color: MColor.hex('#334155'), width: 1),
    padding: const MInsets.all(14),
    child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
      MRow([
        const MText(
          'TODAY',
          style: MTextStyle(color: MColor.hex('#38BDF8'), bold: true, size: 10),
        ),
        const MSpacer(),
        // Stamped by the app so an empty list is distinguishable from a
        // list that never loaded.
        MText(
          MBind('tasks_count'),
          style: const MTextStyle(color: MColor.hex('#64748B'), size: 10),
        ),
      ]),
      const MSizedBox.height(8),
      // One row per entry, bound by key from each map in the list.
      MFlexible(
        child: MListView(
          bind: MBind('tasks'),
          // Rows had no padding at all, so four lines of 13sp text ran
          // together into a wall. Each row is now its own card with breathing
          // room — the difference between a list and a paragraph.
          itemTemplate: MPadding(
            const MInsets.only(bottom: 6),
            MContainer(
              background: const MColor.hex('#1E293B'),
              radius: 10,
              padding: const MInsets.symmetric(horizontal: 10, vertical: 9),
              child: MRow(
                crossAxisAlignment: MCrossAxisAlignment.center,
                [
                  MText(
                    MBind('marker'),
                    style: const MTextStyle(
                      color: MColor.hex('#38BDF8'),
                      size: 13,
                    ),
                  ),
                  const MSizedBox.width(10),
                  MFlexible(
                    child: MText(
                      MBind('title'),
                      maxLines: 1,
                      style: const MTextStyle(
                        color: MColor.hex('#E2E8F0'),
                        size: 13,
                      ),
                    ),
                  ),
                  const MSizedBox.width(8),
                  // The time reads as a chip rather than trailing grey text,
                  // so the eye can scan the column of times on its own.
                  MContainer(
                    background: const MColor.hex('#0F172A'),
                    radius: 6,
                    padding: const MInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: MText(
                      MBind('due'),
                      style: const MTextStyle(
                        color: MColor.hex('#94A3B8'),
                        size: 10,
                        bold: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]),
  ),
);
