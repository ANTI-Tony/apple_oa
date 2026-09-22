# 0013. In-app help in a window, not a help book

Status: Accepted

## Context

macOS draws a Help menu whether or not an app fills it. `App/Info.plist`
declared no `CFBundleHelpBookName`, so the app shipped a Help menu containing
one item that resolves to "Help isn't available for Reporting Builder". A
visibly present, dead menu reads worse than no help at all, and this is a tool
of the kind IS&T ships to people who did not choose it and will never read a
README.

The platform's formal answer is a help book: a `.help` bundle, an `hiutil`
index, and `CFBundleHelpBookName` in the Info.plist, displayed by Help Viewer.

## Decision

Take the platform's *contract* and decline its *container*.

`HelpCommands` replaces `CommandGroup(replacing: .help)` with the standard
title, ⌘?, and two deep links to particular pages. It opens a `Window` scene, so
the guide floats beside the document the way Help Viewer does, joins the Window
menu, closes with ⌘W, and a second ⌘? raises the window that is open rather than
stacking another.

The guide is a **reference, not a re-told tour**. The README narrates the
project for someone deciding whether to clone it; the guide answers "what do I
press" for someone who already has the app open. Almost every line on its four
pages is read out of the app rather than written down a second time: the
shortcut list from `MenuShortcut`, the data path from `AppPaths`, the version
and feature flags from `AppConfiguration`, the remote-processing notice from the
constant the consent dialog already uses. Roughly six sentences are authored,
and none of them appears in the README.

`MenuShortcut` is the point of the exercise. `CardCommands` binds its eighteen
key equivalents from that catalogue and the guide renders its list from the same
values, with the glyphs computed from `key` and `modifiers` rather than stored.
The guide cannot print a shortcut the menu bar does not bind.

## Why not a help book

- **Its failure mode lands on the reviewer's machine.** `helpd` caches book
  registration by bundle identifier and path. An ad-hoc-signed app (`project.yml`)
  launched from DerivedData or from a Gatekeeper-warned download is exactly the
  case where Help Viewer still answers "Help isn't available".
- **It forks the content out of the build.** Help book HTML does not pass
  through the String Catalog that every other user-facing string in this app
  goes through, so it would be the one surface that cannot be localised with the
  rest.
- **It is invisible to the accessibility audit.** Help Viewer is another
  process, so `performAccessibilityAudit()` cannot see it. A window in this app
  is audited by the same test as everything else.
- **It cannot use live values.** The data path, the version and the feature
  flags are read from the running app; static HTML would have to repeat them and
  would drift.

## Consequences

- The Help menu is now the usual corner, and `⌘?` works.
- One new dependency direction: `CardCommands` imports the shortcut catalogue.
  The menu titles are still literals at their call sites and the catalogue
  repeats them for display; unifying those is the obvious next commit, and until
  then the guarantee is about shortcuts, not titles.
- The help window is a second scene that can be focused while the main window is
  not. The Card menu is gated on a card being selected rather than on which
  window is key, so ⌘⌫ still reaches the selected card from the help window.
  That is pre-existing behaviour shared with the Settings scene, and it is not
  changed here.
- `-demoHelp <topic> -uiTesting` opens the guide on a page, which is how the UI
  test and the screenshots reach it.
