import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ====== عدّل أسماء الشخصيات هنا ======
const names = ['الشاب', 'الصغير', 'الأب', 'الجد', 'الولد'];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (d) => Material(
      color: Colors.white,
      child: SingleChildScrollView(
          child: Text('ERROR: ${d.exceptionAsString()}',
              style: const TextStyle(color: Colors.red, fontSize: 12))));
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: MenuScreen()));
}

String facePath(int i) => 'assets/faces/face${i + 1}.png';

// ================= القائمة =================
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4A90E2), Color(0xFFB8E1FF)])),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('مغامرة الوجوه',
                style: TextStyle(
                    fontSize: 34,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('اختر شخصيتك',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GameScreen(i))),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 4)),
                          child: ClipOval(
                              child: Image.asset(facePath(i),
                                  fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 6),
                        Text(names[i],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ================= المراحل =================
class LevelData {
  final int w;
  final List<List<int>> gaps, platforms, coins;
  final List<int> enemies;
  const LevelData(this.w, this.gaps, this.platforms, this.coins, this.enemies);
}

const levels = <LevelData>[
  LevelData(
      45,
      [[14, 17], [30, 33]],
      [[8, 5, 3], [20, 5, 4], [25, 4, 3], [37, 5, 3]],
      [[8, 4], [9, 4], [10, 4], [21, 4], [22, 4], [26, 3], [27, 3], [15, 5],
        [31, 5], [38, 4], [39, 4], [42, 6]],
      [11, 24, 35]),
  LevelData(
      55,
      [[10, 13], [20, 24], [34, 37], [44, 47]],
      [[6, 5, 3], [16, 5, 2], [26, 5, 3], [30, 3, 3], [40, 5, 3]],
      [[6, 4], [7, 4], [8, 4], [21, 4], [22, 4], [30, 2], [31, 2], [35, 5],
        [45, 5], [41, 4], [42, 4]],
      [8, 18, 28, 39, 50]),
  LevelData(
      65,
      [[8, 11], [16, 20], [26, 29], [36, 40], [48, 51], [56, 59]],
      [[13, 5, 2], [22, 5, 3], [32, 4, 3], [44, 5, 3], [53, 5, 2]],
      [[9, 5], [18, 4], [27, 5], [38, 4], [49, 5], [57, 4], [14, 4], [23, 4],
        [33, 3], [45, 4]],
      [6, 14, 24, 31, 42, 46, 54, 60]),
];

class Enemy {
  double x, y, dir = -1;
  bool alive = true;
  Enemy(this.x, this.y);
}

// ================= منطق اللعبة =================
class Game {
  static const rows = 9;
  static const pw = 0.8, ph = 0.95;
  int levelIdx = 0, score = 0, lives = 3, jumpsLeft = 2;
  bool left = false, right = false, jumpQueued = false;
  String state = 'play'; // play | over | win
  double viewW = 16, px = 1.5, py = 5.5, vx = 0, vy = 0, camX = 0, time = 0;
  bool onGround = false;
  late List<List<bool>> solid;
  late List<List<int>> coins;
  late List<Enemy> enemies;
  late List<Rect> blocks;

  LevelData get lv => levels[levelIdx];
  int get flagX => lv.w - 3;

  void loadLevel() {
    final l = lv;
    solid = List.generate(l.w, (_) => List.filled(rows, false));
    blocks = [];
    for (var x = 0; x < l.w; x++) {
      if (!l.gaps.any((g) => x >= g[0] && x < g[1])) {
        solid[x][7] = true;
        solid[x][8] = true;
        blocks.add(Rect.fromLTWH(x.toDouble(), 7, 1, 2));
      }
    }
    for (final p in l.platforms) {
      for (var i = 0; i < p[2]; i++) {
        solid[p[0] + i][p[1]] = true;
        blocks.add(Rect.fromLTWH((p[0] + i).toDouble(), p[1].toDouble(), 1, 1));
      }
    }
    coins = l.coins.map((c) => [c[0], c[1]]).toList();
    enemies = l.enemies.map((x) => Enemy(x.toDouble(), 6.2)).toList();
    respawn();
  }

  void respawn() {
    px = 1.5;
    py = 5.5;
    vx = 0;
    vy = 0;
  }

  void restart() {
    levelIdx = 0;
    score = 0;
    lives = 3;
    state = 'play';
    loadLevel();
  }

  bool solidAt(int tx, int ty) {
    if (tx < 0 || tx >= lv.w) return true;
    if (ty < 0 || ty >= rows) return false;
    return solid[tx][ty];
  }

  void hurt() {
    lives--;
    if (lives <= 0) {
      state = 'over';
    } else {
      respawn();
    }
  }

  void update(double dt) {
    if (state != 'play') return;
    if (dt <= 0) return;
    dt = min(dt, 0.033);
    time += dt;
    vx = ((left ? -1 : 0) + (right ? 1 : 0)) * 6.5;
    if (jumpQueued) {
      if (jumpsLeft > 0) {
        vy = -12;
        jumpsLeft--;
      }
      jumpQueued = false;
    }
    vy = min(vy + 30 * dt, 20);

    px += vx * dt;
    for (var tx = px.floor(); tx <= (px + pw - 0.001).floor(); tx++) {
      for (var ty = py.floor(); ty <= (py + ph - 0.001).floor(); ty++) {
        if (solidAt(tx, ty)) {
          px = vx > 0 ? tx - pw - 0.001 : tx + 1.001;
        }
      }
    }
    py += vy * dt;
    onGround = false;
    for (var tx = px.floor(); tx <= (px + pw - 0.001).floor(); tx++) {
      for (var ty = py.floor(); ty <= (py + ph - 0.001).floor(); ty++) {
        if (solidAt(tx, ty)) {
          if (vy > 0) {
            py = ty - ph;
            onGround = true;
            jumpsLeft = 2;
          } else {
            py = ty + 1.0;
          }
          vy = 0;
        }
      }
    }
    if (py > rows + 1) {
      hurt();
      return;
    }

    coins.removeWhere((c) {
      final hit = (c[0] + 0.5 - (px + pw / 2)).abs() < 0.7 &&
          (c[1] + 0.5 - (py + ph / 2)).abs() < 0.8;
      if (hit) score += 10;
      return hit;
    });

    for (final e in enemies) {
      if (!e.alive) continue;
      e.x += e.dir * 1.5 * dt;
      final front = e.dir > 0 ? (e.x + 0.8).floor() : e.x.floor();
      if (solidAt(front, 6) || !solidAt(front, 7)) e.dir = -e.dir;
      final overlap = px < e.x + 0.8 &&
          px + pw > e.x &&
          py < e.y + 0.8 &&
          py + ph > e.y;
      if (overlap) {
        if (vy > 0 && py + ph < e.y + 0.6) {
          e.alive = false;
          vy = -9;
          jumpsLeft = 1;
          score += 100;
        } else {
          hurt();
          return;
        }
      }
    }

    if (px > flagX) {
      score += 200;
      if (levelIdx + 1 >= levels.length) {
        state = 'win';
      } else {
        levelIdx++;
        loadLevel();
      }
    }
    final maxCam = max(0.0, lv.w - viewW);
    camX = min(max(px - viewW / 2, 0.0), maxCam);
  }
}

// ================= الشاشة =================
class GameScreen extends StatefulWidget {
  final int index;
  const GameScreen(this.index, {super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final g = Game();
  late final Ticker ticker;
  Duration last = Duration.zero;
  bool paused = false;

  @override
  void initState() {
    super.initState();
    g.loadLevel();
    ticker = createTicker((d) {
      final dt = (d - last).inMicroseconds / 1e6;
      last = d;
      if (!paused) g.update(dt);
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(AssetImage(facePath(widget.index)), context);
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  Widget pad(String t, VoidCallback down, VoidCallback up, double size) {
    return Listener(
      onPointerDown: (_) => down(),
      onPointerUp: (_) => up(),
      onPointerCancel: (_) => up(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2)),
        alignment: Alignment.center,
        child: Text(t,
            style: const TextStyle(fontSize: 30, color: Colors.white)),
      ),
    );
  }

  Widget box(double x, double y, double w, double h, Widget child) =>
      Positioned(left: x, top: y, width: w, height: h, child: child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6EC1FF),
      body: LayoutBuilder(builder: (context, c) {
        final t = c.maxHeight / Game.rows;
        g.viewW = c.maxWidth / t;
        final cam = g.camX;
        final kids = <Widget>[];

        // سحب
        for (var i = 0; i < 6; i++) {
          final cx = ((i * 9.0 - cam * 0.4) % (g.viewW + 6)) - 3;
          kids.add(Positioned(
              left: cx * t,
              top: (0.5 + (i % 3) * 1.2) * t,
              child: Icon(Icons.cloud, size: t * 1.8, color: Colors.white)));
        }
        // كتل الأرض والمنصات
        for (final b in g.blocks) {
          if (b.right < cam - 1 || b.left > cam + g.viewW + 1) continue;
          final isGround = b.height > 1;
          kids.add(box(
              (b.left - cam) * t,
              b.top * t,
              b.width * t + 0.5,
              b.height * t + 0.5,
              Container(
                decoration: BoxDecoration(
                    color: isGround
                        ? const Color(0xFF8B5A2B)
                        : const Color(0xFFD2691E),
                    border: Border.all(color: Colors.black26, width: 1)),
                child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                        height: t * 0.22,
                        color: isGround
                            ? const Color(0xFF3CB043)
                            : const Color(0xFFFFB347))),
              )));
        }
        // العملات
        for (final co in g.coins) {
          if (co[0] < cam - 1 || co[0] > cam + g.viewW + 1) continue;
          kids.add(box(
              (co[0] + 0.25 - cam) * t,
              (co[1] + 0.15) * t,
              0.5 * t,
              0.7 * t,
              Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(t),
                      border:
                          Border.all(color: Colors.orange, width: 2)))));
        }
        // العلم
        final fx = (g.flagX - cam) * t;
        kids.add(box(fx + 0.4 * t, 2 * t, 0.1 * t, 5 * t,
            Container(color: Colors.white)));
        kids.add(box(fx + 0.5 * t, 2 * t, 1.0 * t, 0.7 * t,
            Container(color: Colors.red)));
        // الأعداء
        for (final e in g.enemies) {
          if (!e.alive) continue;
          if (e.x < cam - 1 || e.x > cam + g.viewW + 1) continue;
          kids.add(box(
              (e.x - cam) * t,
              e.y * t,
              0.8 * t,
              0.8 * t,
              Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFF7B3F00), shape: BoxShape.circle),
                  child: Center(
                      child: Text('👀', style: TextStyle(fontSize: t * 0.35))))));
        }
        // اللاعب
        final step =
            (g.vx != 0 && g.onGround) ? sin(g.time * 18) * 0.08 * t : 0.0;
        final pxs = (g.px - cam) * t, pys = g.py * t;
        kids.add(Positioned(
            left: pxs,
            top: pys,
            width: Game.pw * t,
            height: Game.ph * t,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                  left: 0.12 * t + step,
                  top: 0.75 * t,
                  width: 0.22 * t,
                  height: 0.2 * t,
                  child: Container(color: const Color(0xFF1E3EA8))),
              Positioned(
                  left: 0.46 * t - step,
                  top: 0.75 * t,
                  width: 0.22 * t,
                  height: 0.2 * t,
                  child: Container(color: const Color(0xFF1E3EA8))),
              Positioned(
                  left: 0.1 * t,
                  top: 0.45 * t,
                  width: 0.6 * t,
                  height: 0.38 * t,
                  child: Container(
                      decoration: BoxDecoration(
                          color: const Color(0xFFE52521),
                          borderRadius: BorderRadius.circular(t * 0.08)))),
              Positioned(
                  left: 0.4 * t - 0.36 * t,
                  top: 0.0,
                  width: 0.72 * t,
                  height: 0.72 * t,
                  child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: ClipOval(
                          child: Image.asset(facePath(widget.index),
                              fit: BoxFit.cover)))),
              Positioned(
                  left: -0.5 * t,
                  top: -0.35 * t,
                  width: 1.8 * t,
                  child: Center(
                      child: Text(names[widget.index],
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: t * 0.3,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 3)
                              ])))),
            ])));

        // الواجهة
        kids.add(Positioned(
            top: 8,
            left: 16,
            child: Text(
                '♥ ${g.lives}    ★ ${g.score}    مرحلة ${g.levelIdx + 1}/${levels.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)]))));
        kids.add(Positioned(
            top: 2,
            right: 8,
            child: Row(children: [
              IconButton(
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white),
                  onPressed: () => setState(() => paused = !paused)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
            ])));
        kids.add(Positioned(
            left: 20,
            bottom: 20,
            child: Row(children: [
              pad('◀', () => g.left = true, () => g.left = false, 76),
              const SizedBox(width: 16),
              pad('▶', () => g.right = true, () => g.right = false, 76),
            ])));
        kids.add(Positioned(
            right: 30,
            bottom: 20,
            child: pad('▲', () => g.jumpQueued = true, () {}, 90)));

        if (g.state != 'play') {
          kids.add(Positioned.fill(
              child: Container(
                  color: Colors.black54,
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(g.state == 'win' ? 'ربحت! 🎉' : 'انتهت اللعبة',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold)),
                    Text('النقاط: ${g.score}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: () => setState(g.restart),
                        child: const Text('العب مجدداً')),
                  ])))));
        }
        return ClipRect(child: Stack(children: kids));
      }),
    );
  }
}
