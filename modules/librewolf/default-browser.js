ObjC.import("CoreServices");

function run(argv) {
  const bundleIdentifier = argv[0];
  const httpsHandler = ObjC.castRefToObject(
    $.LSCopyDefaultHandlerForURLScheme($("https")),
  ).js;
  // macOS confirms a browser change in a dialog, so ask only while it isn't the default.
  if (httpsHandler !== bundleIdentifier) {
    $.LSSetDefaultHandlerForURLScheme($("http"), $(bundleIdentifier));
  }
}
