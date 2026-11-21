/// The main sections of the app, by their index in the navigation.
///
/// Phones show [home], [schedule], [study], [tasks] and [more] in the
/// bottom bar; [subjects] opens from [more] (and the bar then highlights
/// [more]). Computers show all of them in the side rail.
abstract final class AppTabs {
  static const home = 0;
  static const schedule = 1;
  static const study = 2;
  static const tasks = 3;
  static const subjects = 4;
  static const more = 5;

  static const count = 6;
}
