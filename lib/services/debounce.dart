
import 'dart:async';

class Debounce {
  Debounce(this.duration);
  final Duration duration;
  Timer? _timer;

  void run(void Function() fn) {
    _timer?.cancel();
    _timer = Timer(duration, fn);
  }

  void dispose() => _timer?.cancel();
}
