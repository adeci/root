function outputForKey(outputs, key) {
  for (var i = 0; i < outputs.length; i++)
    if (outputs[i].selection_key === key) return outputs[i];
  return null;
}

function outputModel(outputs, activeOnly) {
  var model = [];
  for (var i = 0; i < outputs.length; i++) {
    var output = outputs[i];
    if (!activeOnly || output.active) {
      model.push({
        key: output.selection_key,
        name: output.friendly + " (" + output.name + ")",
      });
    }
  }
  return model;
}

function selectorIndex(model, key) {
  for (var i = 0; i < model.length; i++) if (model[i].key === key) return i;
  return -1;
}

function reconcileSelections(outputs, source, target, initialized) {
  source = source || "";
  target = target || "";
  if (outputs.length === 0)
    return { source: "", target: "", initialized: true };

  if (!initialized) {
    var initialSource = null;
    for (var i = 0; i < outputs.length; i++)
      if (outputs[i].active && outputs[i].focused) {
        initialSource = outputs[i];
        break;
      }
    if (initialSource === null)
      for (var j = 0; j < outputs.length; j++)
        if (outputs[j].active) {
          initialSource = outputs[j];
          break;
        }
    source = initialSource === null ? "" : initialSource.selection_key;
    for (var k = 0; k < outputs.length; k++)
      if (outputs[k].active && outputs[k].selection_key !== source) {
        target = outputs[k].selection_key;
        break;
      }
    return { source: source, target: target, initialized: true };
  }

  // Do not replace a stale selection: a new DP-1 requires a new choice.
  if (outputForKey(outputs, source) === null) source = "";
  if (outputForKey(outputs, target) === null || target === source) target = "";
  return { source: source, target: target, initialized: true };
}

function validActivePair(outputs, source, target) {
  var sourceOutput = outputForKey(outputs, source);
  var targetOutput = outputForKey(outputs, target);
  return (
    sourceOutput !== null &&
    sourceOutput.active === true &&
    targetOutput !== null &&
    targetOutput.active === true &&
    source !== target
  );
}

function validExtendPair(outputs, source, target) {
  var sourceOutput = outputForKey(outputs, source);
  return (
    sourceOutput !== null &&
    sourceOutput.active === true &&
    outputForKey(outputs, target) !== null &&
    source !== target
  );
}

function mirrorArguments(outputs, source, target) {
  if (!validActivePair(outputs, source, target)) return null;
  return [
    "mirror",
    "--source",
    outputForKey(outputs, source).name,
    "--source-key",
    source,
    "--target",
    outputForKey(outputs, target).name,
    "--target-key",
    target,
  ];
}

function extendArguments(outputs, source, target) {
  if (!validExtendPair(outputs, source, target)) return null;
  return ["extend", outputForKey(outputs, target).name, "--target-key", target];
}

function placeArguments(outputs, source, target, direction) {
  if (!validActivePair(outputs, source, target)) return null;
  return [
    "place",
    outputForKey(outputs, target).name,
    direction,
    outputForKey(outputs, source).name,
    "--target-key",
    target,
    "--reference-key",
    source,
  ];
}

function statusState(actionRunning, actionError, refreshError, successMessage) {
  if (actionRunning)
    return { text: "Applying display change...", isError: false };
  if (actionError !== "") return { text: actionError, isError: true };
  if (refreshError !== "") return { text: refreshError, isError: true };
  if (successMessage !== "") return { text: successMessage, isError: false };
  return { text: "", isError: false };
}

function statusSlotHeight(fontSize, margin) {
  return Math.round(fontSize * 3.6 + margin);
}
