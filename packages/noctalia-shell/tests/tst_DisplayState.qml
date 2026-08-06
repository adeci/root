import QtQuick
import QtTest
import "../plugins/niri-display/DisplayState.js" as DisplayState

TestCase {
  name: "DisplayState"

  function output(name, key, active, focused) {
    return {
      "name": name,
      "friendly": name,
      "selection_key": key,
      "active": active,
      "focused": focused
    };
  }

  function test_replaced_connector_and_empty_topology_clear_selections() {
    var oldA = output("DP-1", "A", true, true);
    var newB = output("DP-1", "B", true, true);
    var replacement = DisplayState.reconcileSelections([newB], oldA.selection_key,
                                                        oldA.selection_key, true);
    compare(replacement.source, "");
    compare(replacement.target, "");
    verify(replacement.initialized);

    var empty = DisplayState.reconcileSelections([], "A", "C", true);
    compare(empty.source, "");
    compare(empty.target, "");
    verify(empty.initialized);
  }

  function test_stale_selection_is_not_selectable_or_actionable() {
    var oldA = output("DP-1", "A", true, true);
    var newB = output("DP-1", "B", true, true);
    var model = DisplayState.outputModel([newB], false);
    compare(DisplayState.selectorIndex(model, oldA.selection_key), -1);
    verify(!DisplayState.validActivePair([newB], oldA.selection_key, "C"));
    compare(DisplayState.mirrorArguments([newB], oldA.selection_key, "C"), null);
  }

  function test_current_selection_builds_keyed_action() {
    var source = output("DP-1", "B", true, true);
    var target = output("HDMI-A-1", "C", true, false);
    compare(
      DisplayState.mirrorArguments([source, target], source.selection_key, target.selection_key),
      ["mirror", "--source", "DP-1", "--source-key", "B",
       "--target", "HDMI-A-1", "--target-key", "C"]
    );
    compare(
      DisplayState.extendArguments([source, target], source.selection_key, target.selection_key),
      ["extend", "HDMI-A-1", "--target-key", "C"]
    );
  }
}
