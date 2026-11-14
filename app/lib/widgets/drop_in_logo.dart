import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme.dart';

/// spring as a Curve
class SpringCurve extends Curve {
  const SpringCurve({this.stiffness = 170, this.damping = 13, this.seconds = 1.2});

  final double stiffness, damping, seconds;

  @override
  double transformInternal(double t) =>
      SpringSimulation(SpringDescription(mass: 1, stiffness: stiffness, damping: damping), 0, 1, 0).x(t * seconds);
}

const _spring = SpringCurve();
const _bouncy = SpringCurve(stiffness: 260, damping: 11);
const _emph = Cubic(.2, 0, 0, 1);
const _accel = Cubic(.3, 0, .8, .15);
const _out = Cubic(.25, 1, .5, 1);

/// keyframes (ms, value, curve)
class _Track {
  const _Track(this.keys);

  final List<(int, double, Curve)> keys;

  double at(double ms) {
    if (ms <= keys.first.$1) return keys.first.$2;
    for (var i = 1; i < keys.length; i++) {
      final (t1, v1, c) = keys[i];
      if (ms <= t1) {
        final (t0, v0, _) = keys[i - 1];
        final k = t1 == t0 ? 1.0 : c.transform(((ms - t0) / (t1 - t0)).clamp(0, 1));
        return v0 + (v1 - v0) * k;
      }
    }
    return keys.last.$2;
  }
}

const dropInMs = 3700;
const dropInTextMs = 3150;

/// welcome logo animation, [ms] = time since start
class DropInLogo extends StatelessWidget {
  const DropInLogo({super.key, required this.ms, this.size = 360});

  final double ms;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _Painter(ms, c.primaryContainer, c.primary, c.onPrimaryContainer)),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.ms, this.tile, this.bar, this.dot);

  final double ms;
  final Color tile, bar, dot;

  // 360 square, scaled
  static const _end = (tile: 168.0, ax: 180 - 21.12 * 1.68, bx: 180 + 21.12 * 1.68, bw: 13.2 * 1.68, bh: 36.96 * 1.68, d: 19.8 * 1.68);
  static const _floor = 252.0, _bigW = 40.0, _bigH = 112.0, _ball = 60.0;
  static const _by = _floor - _bigH / 2, _cy = _floor - _ball / 2;

  static final _a = (
    x: _Track([(0, 70, _emph), (1700, 70, _emph), (1850, 64, _spring), (2300, 70, _spring), (2650, 70, _emph), (3350, _end.ax, _emph)]),
    y: _Track([(0, -200, _emph), (150, -200, _emph), (900, _by, _bouncy), (2650, _by, _emph), (3350, 180, _emph)]),
    r: _Track([(0, 0, _emph), (1700, 0, _emph), (1850, -9, _spring), (2300, 0, _spring)]),
    k: _Track([(0, 0, _emph), (2650, 0, _emph), (3350, 1, _emph)]),
  );
  static final _b = (
    x: _Track([(0, 290, _emph), (2050, 290, _emph), (2200, 296, _spring), (2650, 290, _spring), (3350, _end.bx, _emph)]),
    y: _Track([(0, -200, _emph), (350, -200, _emph), (1100, _by, _bouncy), (2650, _by, _emph), (3350, 180, _emph)]),
    r: _Track([(0, 0, _emph), (2050, 0, _emph), (2200, 9, _spring), (2650, 0, _spring)]),
    k: _Track([(0, 0, _emph), (2650, 0, _emph), (3350, 1, _emph)]),
  );
  static final _c = (
    x: _Track([(0, 180, _emph), (1300, 180, _emph), (1700, 120, Curves.easeInOut), (2050, 240, Curves.easeInOut), (2400, 180, _out)]),
    y: _Track([(0, -160, _emph), (650, -160, _emph), (1050, _cy, _accel), (1130, _cy + 6, _out), (1300, _cy, Curves.easeInOut),
      (2650, _cy + 4, _out), (3000, 120, Curves.easeInOut), (3350, 180, Curves.easeInOut)]),
    sx: _Track([(0, 1, _emph), (1050, 1, _emph), (1130, 1.18, _out), (1300, 1, Curves.easeInOut), (1700, .9, Curves.easeInOut), (1760, 1, Curves.easeInOut),
      (2050, .9, Curves.easeInOut), (2110, 1, Curves.easeInOut), (2400, 1, _out), (2650, 1.12, _out), (3000, .95, Curves.easeInOut), (3350, 1, Curves.easeInOut)]),
    sy: _Track([(0, 1, _emph), (1050, 1, _emph), (1130, .8, _out), (1300, 1, Curves.easeInOut), (1700, 1.08, Curves.easeInOut), (1760, 1, Curves.easeInOut),
      (2050, 1.08, Curves.easeInOut), (2110, 1, Curves.easeInOut), (2400, 1, _out), (2650, .88, _out), (3000, 1.05, Curves.easeInOut), (3350, 1, Curves.easeInOut)]),
    d: _Track([(0, _ball, _emph), (2650, _ball, _emph), (3000, 40, Curves.easeInOut), (3350, _end.d, Curves.easeInOut)]),
  );
  static final _tileScale = _Track([(0, 0, _emph), (2950, 0, _emph), (3700, 1, _bouncy)]);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 360;
    canvas.scale(s);

    final ts = _tileScale.at(ms);
    if (ts > 0) {
      final w = _end.tile * ts;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(180, 180), width: w, height: w), Radius.circular(w * .28)),
        Paint()..color = tile.withValues(alpha: ts.clamp(0, 1)),
      );
    }

    void barAt(double x, double y, double rot, double k) {
      final w = _bigW + (_end.bw - _bigW) * k, h = _bigH + (_end.bh - _bigH) * k;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot * 3.14159265 / 180);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(w / 2)), Paint()..color = bar);
      canvas.restore();
    }

    barAt(_a.x.at(ms), _a.y.at(ms), _a.r.at(ms), _a.k.at(ms));
    barAt(_b.x.at(ms), _b.y.at(ms), _b.r.at(ms), _b.k.at(ms));

    final d = _c.d.at(ms);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_c.x.at(ms), _c.y.at(ms)), width: d * _c.sx.at(ms), height: d * _c.sy.at(ms)),
      Paint()..color = dot,
    );
  }

  @override
  bool shouldRepaint(_Painter old) => old.ms != ms || old.bar != bar || old.tile != tile;
}
