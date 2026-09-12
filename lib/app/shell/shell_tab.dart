import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-navigation tab is showing.
///
/// Held outside [AppShell] so a screen on one tab can open another — Home's
/// "Uparjon" tile jumps to the earning tab without the shell exposing its
/// state widget.
final shellTabProvider = NotifierProvider<ShellTab, int>(ShellTab.new);

class ShellTab extends Notifier<int> {
  static const int home = 0;
  static const int earn = 1;
  static const int wallet = 2;
  static const int menu = 3;

  @override
  int build() => home;

  void select(int index) => state = index;
}
