import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);

/// Key for the MainScreen Scaffold — owned by MainScreen, read by inner
/// screens that need to open the shared app drawer.
final mainScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(),
);
