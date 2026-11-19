import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
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
  Snd.init();
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: MenuScreen()));
}

String facePath(int i) => 'assets/faces/face${i + 1}.png';

// ================= الصوت =================
class Snd {
  static bool on = true;
  static final _pool = List.generate(6, (_) => AudioPlayer());
  static int _i = 0;
  static final _music = AudioPlayer();
  static Future<void> init() async {
    try {
      for (final p in _pool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.3);
    } catch (_) {}
  }

  static void play(String n) {
    if (!on) return;
    try {
      final p = _pool[_i++ % _pool.length];
      p.play(AssetSource('sfx/$n.wav'), volume: 0.8).catchError((_) {});
    } catch (_) {}
  }

  static void music(int world) {
    if (!on) return;
    try {
      _music.play(AssetSource('music/w$world.wav')).catchError((_) {});
    } catch (_) {}
  }

  static void stopMusic() {
    try {
      _music.stop();
    } catch (_) {}
  }
}

// ================= العوالم =================
class Th {
  final String name;
  final List<Color> bg;
  final Color ground, groundTop, plat, platTop, walker;
  final bool lava;
  const Th(this.name, this.bg, this.ground, this.groundTop, this.plat,
      this.platTop, this.walker, this.lava);
}

const themes = <Th>[
  Th('العالم العلوي', [Color(0xFF4A90E2), Color(0xFFB8E1FF)], Color(0xFF8B5A2B),
      Color(0xFF3CB043), Color(0xFFD2691E), Color(0xFFFFB347), Color(0xFF7B3F00), false),
  Th('العالم السفلي', [Color(0xFF14142B), Color(0xFF2D2D52)], Color(0xFF4A4A63),
      Color(0xFF7C7CA0), Color(0xFF5E5E80), Color(0xFF9A9AC0), Color(0xFF3B6B3B), true),
  Th('عالم السماء', [Color(0xFF3B1F6E), Color(0xFFFF9AA2)], Color(0xFFE8E8F5),
      Color(0xFFFFFFFF), Color(0xFF9AD0FF), Color(0xFFD6ECFF), Color(0xFF6A4C93), false),
  Th('القلعة النارية', [Color(0xFF2B0A0A), Color(0xFF7A1F1F)], Color(0xFF3A3A3A),
      Color(0xFFB03A2E), Color(0xFF555555), Color(0xFFE67E22), Color(0xFF1C1C1C), true),
];
const bossEmoji = ['👹', '🐲', '🦑', '😈'];

// ================= المراحل (تُولَّد تلقائياً) =================
class LevelData {
  final int w;
  final Set<int> gaps;
  final List<List<int>> plats, coins, enemies, hearts;
  final List<int> spikes;
  final bool boss;
  LevelData(this.w, this.gaps, this.plats, this.coins, this.enemies,
      this.spikes, this.hearts, this.boss);
}

LevelData makeLevel(int wd, int n) {
  final r = Random(wd * 131 + n * 17 + 5);
  final gaps = <int>{};
  final plats = <List<int>>[], coins = <List<int>>[], en = <List<int>>[];
  final hearts = <List<int>>[];
  final spikes = <int>[];
  if (n == 2) {
    plats.addAll([[3, 5, 3], [14, 5, 3]]);
    return LevelData(20, gaps, plats, coins, en, spikes, hearts, true);
  }
  final w = 46 + wd * 6 + n * 10;
  var x = 9;
  var heart = false;
  while (x < w - 9) {
    var k = r.nextInt(6);
    if (wd >= 2 && k >= 2 && r.nextBool()) k = 0;
    if (wd == 0 && k == 4) k = 2;
    if (wd == 0 && n == 0 && k == 3) k = 5;
    if (k == 0) {
      final len = 2 + r.nextInt(wd == 0 ? 2 : 3);
      for (var i = 0; i < len; i++) {
        gaps.add(x + i);
        coins.add([x + i, 5]);
      }
      x += len + 5;
    } else if (k == 1) {
      final len = 3 + r.nextInt(3), y = 4 + r.nextInt(2);
      plats.add([x, y, len]);
      for (var i = 0; i < len; i++) {
        coins.add([x + i, y - 1]);
      }
      if (!heart && r.nextInt(3) == 0) {
        hearts.add([x + 1, y - 2]);
        heart = true;
      }
      x += len + 3;
    } else if (k == 2) {
      en.add([x, 0]);
      x += 4;
    } else if (k == 3) {
      spikes.add(x);
      if (wd > 0) spikes.add(x + 1);
      x += 5;
    } else if (k == 4) {
      en.add([x, 1]);
      x += 5;
    } else {
      for (var i = 0; i < 4; i++) {
        coins.add([x + i, 6]);
      }
      x += 5;
    }
  }
  if (!heart) hearts.add([w - 14, 5]);
  return LevelData(w, gaps, plats, coins, en, spikes, hearts, false);
}

// ================= الكيانات =================
class Enemy {
  double x, y, dir = -1, x0, base, ph;
  int type;
  bool alive = true;
  Enemy(this.x, this.y, this.type)
      : x0 = x,
        base = y,
        ph = x * 0.7;
}

class Boss {
  double x = 14, y = 4.8, vy = 0, dir = -1, inv = 0, shootT = 2, jumpT = 3, turnT = 2;
  int hp, maxHp;
  double speed, shootEvery, jumpEvery;
  bool dead = false;
  Boss(this.hp, this.speed, this.shootEvery, this.jumpEvery) : maxHp = hp;
}

class Fire {
  double x, y, vx;
  Fire(this.x, this.y, this.vx);
}

class P {
  double x, y, vx, vy, life, max, size;
  Color c;
  String? text;
  P(this.x, this.y, this.vx, this.vy, this.life, this.size, this.c, [this.text])
      : max = life;
}

// ================= منطق اللعبة =================
class Game {
  static const rows = 9;
  static const pw = 0.8, ph = 0.95;
  static const totalLevels = 12;
  void Function(String) sfx = (_) {};
  int levelIdx, score = 0, lives = 3, jumpsLeft = 2;
  bool left = false, right = false, jumpQueued = false, onGround = false;
  String state = 'play'; // play | trans | over | win
  String banner = '';
  double bannerT = 0, transT = 0, shake = 0, flash = 0, invul = 0;
  double viewW = 16, px = 1.5, py = 5.5, vx = 0, vy = 0, camX = 0, time = 0;
  double safeX = 1.5, safeY = 5.5;
  late LevelData lv;
  late List<List<bool>> solid;
  late List<List<int>> coins, hearts;
  late List<Enemy> enemies;
  late List<Rect> blocks;
  List<Fire> fires = [];
  List<P> parts = [];
  Boss? boss;
  final rnd = Random();

  Game(int startWorld) : levelIdx = startWorld * 3;
  int get world => levelIdx ~/ 3;
  int get sub => levelIdx % 3;
  int get flagX => lv.w - 3;

  void loadLevel() {
    lv = makeLevel(world, sub);
    final l = lv;
    solid = List.generate(l.w, (_) => List.filled(rows, false));
    blocks = [];
    for (var x = 0; x < l.w; x++) {
      if (!l.gaps.contains(x)) {
        solid[x][7] = true;
        solid[x][8] = true;
        blocks.add(Rect.fromLTWH(x.toDouble(), 7, 1, 2));
      }
    }
    for (final p in l.plats) {
      for (var i = 0; i < p[2]; i++) {
        solid[p[0] + i][p[1]] = true;
        blocks.add(Rect.fromLTWH((p[0] + i).toDouble(), p[1].toDouble(), 1, 1));
      }
    }
    coins = l.coins.map((c) => [c[0], c[1]]).toList();
    hearts = l.hearts.map((c) => [c[0], c[1]]).toList();
    enemies = l.enemies
        .map((e) => Enemy(e[0].toDouble(), e[1] == 0 ? 6.2 : 4.6, e[1]))
        .toList();
    fires = [];
    boss = l.boss
        ? Boss(4 + world, 2.0 + world * 0.5, 2.6 - world * 0.3, 3.2 - world * 0.3)
        : null;
    px = 2;
    py = 5.5;
    vx = vy = 0;
    safeX = px;
    safeY = py;
    invul = 1;
    banner = l.boss
        ? '⚔️ زعيم ${themes[world].name}'
        : '${themes[world].name}  ${world + 1}-${sub + 1}';
    bannerT = 2.2;
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

  void emit(double x, double y, int n, Color c,
      {double speed = 4, double size = 0.12, double life = 0.6}) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 2 * pi, s = rnd.nextDouble() * speed;
      parts.add(P(x, y, cos(a) * s, sin(a) * s - 1, life * (0.5 + rnd.nextDouble()),
          size, c));
    }
  }

  void floatText(double x, double y, String t) =>
      parts.add(P(x, y, 0, -1.5, 0.9, 0.4, Colors.white, t));

  void hurt() {
    if (invul > 0 || state != 'play') return;
    lives--;
    sfx('hurt');
    flash = 0.35;
    shake = 0.25;
    invul = 2;
    vy = -8;
    emit(px + 0.4, py + 0.5, 10, Colors.redAccent);
    if (lives <= 0) {
      state = 'over';
      sfx('over');
    }
  }

  void fall() {
    lives--;
    sfx('hurt');
    flash = 0.35;
    if (lives <= 0) {
      state = 'over';
      sfx('over');
      return;
    }
    px = safeX;
    py = safeY;
    vy = 0;
    invul = 2;
  }

  void next() {
    if (levelIdx + 1 >= totalLevels) {
      state = 'win';
      sfx('win');
      return;
    }
    levelIdx++;
    state = 'play';
    loadLevel();
  }

  void finish(String msg, String snd) {
    state = 'trans';
    transT = 2.0;
    banner = msg;
    bannerT = 2.0;
    sfx(snd);
  }

  void updateParts(double dt) {
    for (final p in parts) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.text == null) p.vy += 12 * dt;
    }
    parts.removeWhere((p) => p.life <= 0);
  }

  void update(double dt) {
    if (dt <= 0) return;
    dt = min(dt, 0.033);
    time += dt;
    shake = max(0, shake - dt);
    flash = max(0, flash - dt);
    invul = max(0, invul - dt);
    bannerT = max(0, bannerT - dt);
    updateParts(dt);
    if (state == 'trans') {
      transT -= dt;
      if (transT <= 0) next();
      return;
    }
    if (state != 'play') return;

    vx = ((left ? -1 : 0) + (right ? 1 : 0)) * 6.5;
    if (jumpQueued) {
      if (jumpsLeft > 0) {
        if (!onGround) emit(px + 0.4, py + ph, 6, Colors.white70, speed: 2);
        vy = -12;
        jumpsLeft--;
        sfx('jump');
      }
      jumpQueued = false;
    }
    final prevVy = vy;
    vy = min(vy + 30 * dt, 20);

    px += vx * dt;
    for (var tx = px.floor(); tx <= (px + pw - 0.001).floor(); tx++) {
      for (var ty = py.floor(); ty <= (py + ph - 0.001).floor(); ty++) {
        if (solidAt(tx, ty)) px = vx > 0 ? tx - pw - 0.001 : tx + 1.001;
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
            if (prevVy > 9) emit(px + 0.4, py + ph, 6, Colors.white54, speed: 2);
          } else {
            py = ty + 1.0;
          }
          vy = 0;
        }
      }
    }
    if (onGround) {
      final ty = (py + ph + 0.05).floor();
      if (solidAt((px + 0.05).floor(), ty) && solidAt((px + pw - 0.05).floor(), ty)) {
        safeX = px;
        safeY = py;
      }
    }
    if (py > rows + 1) {
      fall();
      return;
    }

    for (final s in lv.spikes) {
      if (px + pw > s + 0.2 && px < s + 0.8 && py + ph > 6.55) hurt();
    }
    coins.removeWhere((c) {
      final hit = (c[0] + 0.5 - (px + pw / 2)).abs() < 0.7 &&
          (c[1] + 0.5 - (py + ph / 2)).abs() < 0.8;
      if (hit) {
        score += 10;
        sfx('coin');
        emit(c[0] + 0.5, c[1] + 0.5, 6, const Color(0xFFFFD700), speed: 3, size: 0.1);
      }
      return hit;
    });
    hearts.removeWhere((c) {
      final hit = (c[0] + 0.5 - (px + pw / 2)).abs() < 0.8 &&
          (c[1] + 0.5 - (py + ph / 2)).abs() < 0.9;
      if (hit) {
        lives = min(lives + 1, 5);
        sfx('heart');
        emit(c[0] + 0.5, c[1] + 0.5, 12, Colors.pinkAccent, speed: 4);
        floatText(c[0].toDouble(), c[1].toDouble(), '+♥');
      }
      return hit;
    });

    for (final e in enemies) {
      if (!e.alive) continue;
      if (e.type == 0) {
        e.x += e.dir * 1.5 * dt;
        final front = e.dir > 0 ? (e.x + 0.8).floor() : e.x.floor();
        if (solidAt(front, 6) || !solidAt(front, 7)) e.dir = -e.dir;
      } else {
        e.x = e.x0 + sin(time * 1.2 + e.ph) * 3;
        e.y = e.base + sin(time * 2.4 + e.ph) * 0.5;
      }
      if (px < e.x + 0.8 && px + pw > e.x && py < e.y + 0.8 && py + ph > e.y) {
        if (vy > 0 && py + ph < e.y + 0.6) {
          e.alive = false;
          vy = -9;
          jumpsLeft = 1;
          score += 100;
          sfx('stomp');
          shake = 0.1;
          emit(e.x + 0.4, e.y + 0.4, 10, themes[world].walker, speed: 4);
          floatText(e.x, e.y - 0.3, '+100');
        } else {
          hurt();
        }
      }
    }

    final b = boss;
    if (b != null && !b.dead) updateBoss(b, dt);
    for (final f in fires) {
      f.x += f.vx * dt;
      if (px < f.x + 0.5 && px + pw > f.x && py < f.y + 0.5 && py + ph > f.y) {
        f.x = -99;
        hurt();
      }
    }
    fires.removeWhere((f) => f.x < -1 || f.x > lv.w + 1);

    if (!lv.boss && px > flagX) {
      score += 200;
      finish('أحسنت! 🎉', 'clear');
    }
    camX = min(max(px - viewW / 2, 0.0), max(0.0, lv.w - viewW));
  }

  void updateBoss(Boss b, double dt) {
    b.inv = max(0, b.inv - dt);
    b.turnT -= dt;
    b.shootT -= dt;
    b.jumpT -= dt;
    if (b.turnT <= 0) {
      b.dir = px > b.x ? 1 : -1;
      b.turnT = 1.5 + rnd.nextDouble() * 1.5;
    }
    b.x += b.dir * b.speed * dt;
    if (b.x < 1) {
      b.x = 1;
      b.dir = 1;
    }
    if (b.x > lv.w - 1 - 2.2) {
      b.x = lv.w - 3.2;
      b.dir = -1;
    }
    b.vy += 30 * dt;
    b.y += b.vy * dt;
    if (b.y > 4.8) {
      if (b.vy > 6) {
        shake = 0.3;
        emit(b.x + 1.1, 7, 8, Colors.brown, speed: 3);
      }
      b.y = 4.8;
      b.vy = 0;
      if (b.jumpT <= 0) {
        b.vy = -14;
        b.jumpT = b.jumpEvery + rnd.nextDouble();
      }
    }
    if (b.shootT <= 0) {
      b.shootT = b.shootEvery + rnd.nextDouble() * 0.8;
      final dir = px > b.x ? 1.0 : -1.0;
      final high = world > 0 && rnd.nextBool();
      fires.add(Fire(b.x + 1.1, high ? 5.0 : 6.4, dir * (5.0 + world)));
      sfx('shoot');
    }
    if (px < b.x + 2.0 && px + pw > b.x + 0.2 && py < b.y + 2.2 && py + ph > b.y) {
      if (vy > 0 && py + ph < b.y + 1.0) {
        vy = -12;
        jumpsLeft = 1;
        if (b.inv <= 0) {
          b.hp--;
          b.inv = 1.0;
          shake = 0.35;
          sfx('bossHit');
          emit(b.x + 1.1, b.y + 0.5, 14, Colors.orangeAccent, speed: 5);
          floatText(b.x + 0.8, b.y - 0.3, '-1');
          if (b.hp <= 0) {
            b.dead = true;
            fires.clear();
            score += 1000;
            emit(b.x + 1.1, b.y + 1.1, 50, Colors.deepOrange, speed: 8, size: 0.2, life: 1.2);
            emit(b.x + 1.1, b.y + 1.1, 30, Colors.yellow, speed: 6, size: 0.15, life: 1.0);
            shake = 0.8;
            finish('هزمت الزعيم! 🏆', 'boom');
          }
        }
      } else if (b.inv <= 0) {
        hurt();
      }
    }
  }
}

// ================= القائمة =================
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int ch = 0, wd = 0;
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
                    fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 5; i++)
                GestureDetector(
                  onTap: () => setState(() => ch = i),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: ch == i ? Colors.yellow : Colors.white,
                                width: ch == i ? 5 : 2)),
                        child: ClipOval(
                            child: Image.asset(facePath(i), fit: BoxFit.cover)),
                      ),
                      Text(names[i],
                          style: TextStyle(
                              color: ch == i ? Colors.yellow : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 4; i++)
                GestureDetector(
                  onTap: () => setState(() => wd = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: themes[i].bg),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: wd == i ? Colors.yellow : Colors.white54,
                            width: wd == i ? 3 : 1)),
                    child: Text('${i + 1}. ${themes[i].name}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GameScreen(ch, wd))),
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Text('ابدأ اللعب', style: TextStyle(fontSize: 20)))),
          ]),
        ),
      ),
    );
  }
}

// ================= شاشة اللعب =================
class GameScreen extends StatefulWidget {
  final int index, startWorld;
  const GameScreen(this.index, this.startWorld, {super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Game g;
  late final Ticker ticker;
  Duration last = Duration.zero;
  bool paused = false;
  int musicWorld = -1;
  final rnd = Random();

  @override
  void initState() {
    super.initState();
    g = Game(widget.startWorld)
      ..sfx = Snd.play
      ..loadLevel();
    ticker = createTicker((d) {
      final dt = (d - last).inMicroseconds / 1e6;
      last = d;
      if (!paused) g.update(dt);
      if (g.world != musicWorld && g.state != 'win') {
        musicWorld = g.world;
        Snd.music(musicWorld);
      }
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
    Snd.stopMusic();
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
        child: Text(t, style: const TextStyle(fontSize: 30, color: Colors.white)),
      ),
    );
  }

  Widget box(double x, double y, double w, double h, Widget child) =>
      Positioned(left: x, top: y, width: w, height: h, child: child);

  Widget dot(double x, double y, double s, Color c) => Positioned(
      left: x,
      top: y,
      width: s,
      height: s,
      child: DecoratedBox(decoration: BoxDecoration(color: c, shape: BoxShape.circle)));

  @override
  Widget build(BuildContext context) {
    final th = themes[g.world];
    return Scaffold(
      backgroundColor: th.bg[0],
      body: LayoutBuilder(builder: (context, c) {
        final t = c.maxHeight / Game.rows;
        g.viewW = c.maxWidth / t;
        final cam = g.camX;
        final kids = <Widget>[];
        kids.add(Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: th.bg)))));

        // خلفية متحركة لكل عالم
        for (var i = 0; i < 14; i++) {
          final fx = ((i * 7.3 - cam * 0.3) % (g.viewW + 6)) - 3;
          if (g.world == 0) {
            if (i < 6) {
              kids.add(Positioned(
                  left: fx * t,
                  top: (0.5 + (i % 3) * 1.2) * t,
                  child: Icon(Icons.cloud, size: t * 1.8, color: Colors.white)));
            }
          } else if (g.world == 2) {
            final o = 0.3 + 0.7 * sin(g.time * 2 + i).abs();
            kids.add(Positioned(
                left: fx * t,
                top: ((i * 0.61) % 6) * t,
                child: Opacity(
                    opacity: o, child: const Text('✦', style: TextStyle(color: Colors.white, fontSize: 14)))));
          } else if (g.world == 1) {
            kids.add(dot(fx * t, ((i * 1.7 + g.time * 0.3) % 9) * t, 4, Colors.white24));
          } else {
            kids.add(dot(fx * t, (9 - ((i * 1.3 + g.time * 1.2) % 9)) * t, 5, Colors.orangeAccent));
          }
        }
        if (th.lava) {
          kids.add(Positioned(
              left: 0,
              right: 0,
              top: 8.3 * t,
              height: 0.8 * t,
              child: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFF6A00), Color(0xFFB30000)])))));
        }
        for (final b in g.blocks) {
          if (b.right < cam - 1 || b.left > cam + g.viewW + 1) continue;
          final ground = b.height > 1;
          kids.add(box(
              (b.left - cam) * t, b.top * t, b.width * t + 0.5, b.height * t + 0.5,
              Container(
                decoration: BoxDecoration(
                    color: ground ? th.ground : th.plat,
                    border: Border.all(color: Colors.black26, width: 1)),
                child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                        height: t * 0.22, color: ground ? th.groundTop : th.platTop)),
              )));
        }
        for (final s in g.lv.spikes) {
          if (s < cam - 1 || s > cam + g.viewW + 1) continue;
          kids.add(Positioned(
              left: (s - cam) * t,
              top: 6.0 * t,
              width: t,
              child: Text('▲',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade300, fontSize: t * 0.95, height: 1))));
        }
        for (final co in g.coins) {
          if (co[0] < cam - 1 || co[0] > cam + g.viewW + 1) continue;
          final wv = 0.15 + 0.35 * cos(g.time * 6 + co[0]).abs();
          kids.add(box(
              (co[0] + 0.5 - wv / 2 - cam) * t, (co[1] + 0.15) * t, wv * t, 0.7 * t,
              Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(t),
                      border: Border.all(color: Colors.orange, width: 1.5)))));
        }
        for (final h in g.hearts) {
          if (h[0] < cam - 1 || h[0] > cam + g.viewW + 1) continue;
          final bob = sin(g.time * 4 + h[0]) * 0.1;
          kids.add(Positioned(
              left: (h[0] - cam) * t,
              top: (h[1] + bob) * t,
              child: Text('❤️', style: TextStyle(fontSize: t * 0.8))));
        }
        if (!g.lv.boss) {
          final fx = (g.flagX - cam) * t;
          kids.add(box(fx + 0.4 * t, 2 * t, 0.1 * t, 5 * t, Container(color: Colors.white)));
          kids.add(box(fx + 0.5 * t, 2 * t, 1.0 * t, 0.7 * t, Container(color: Colors.red)));
        }
        for (final e in g.enemies) {
          if (!e.alive || e.x < cam - 4 || e.x > cam + g.viewW + 4) continue;
          kids.add(box(
              (e.x - cam) * t, e.y * t, 0.8 * t, 0.8 * t,
              e.type == 0
                  ? Container(
                      decoration: BoxDecoration(color: th.walker, shape: BoxShape.circle),
                      child: Center(child: Text('👀', style: TextStyle(fontSize: t * 0.35))))
                  : Center(child: Text('🦇', style: TextStyle(fontSize: t * 0.8, height: 1)))));
        }
        final b = g.boss;
        if (b != null && !b.dead) {
          final blink = b.inv > 0 && (g.time * 14).floor().isEven;
          kids.add(box(
              (b.x - cam) * t, b.y * t, 2.2 * t, 2.2 * t,
              Opacity(
                  opacity: blink ? 0.3 : 1,
                  child: FittedBox(child: Text(bossEmoji[g.world])))));
        }
        for (final f in g.fires) {
          kids.add(Positioned(
              left: (f.x - cam) * t,
              top: f.y * t,
              width: 0.5 * t,
              height: 0.5 * t,
              child: const DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.red, blurRadius: 10)]))));
        }

        // اللاعب
        final step = (g.vx != 0 && g.onGround) ? sin(g.time * 18) * 0.08 * t : 0.0;
        final blinkP = g.invul > 0 && (g.time * 12).floor().isEven;
        kids.add(Positioned(
            left: (g.px - cam) * t,
            top: g.py * t,
            width: Game.pw * t,
            height: Game.ph * t,
            child: Opacity(
              opacity: blinkP ? 0.35 : 1,
              child: Stack(clipBehavior: Clip.none, children: [
                box(0.12 * t + step, 0.75 * t, 0.22 * t, 0.2 * t,
                    Container(color: const Color(0xFF1E3EA8))),
                box(0.46 * t - step, 0.75 * t, 0.22 * t, 0.2 * t,
                    Container(color: const Color(0xFF1E3EA8))),
                box(0.1 * t, 0.45 * t, 0.6 * t, 0.38 * t,
                    Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFFE52521),
                            borderRadius: BorderRadius.circular(t * 0.08)))),
                box(0.04 * t, 0, 0.72 * t, 0.72 * t,
                    Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: ClipOval(
                            child: Image.asset(facePath(widget.index), fit: BoxFit.cover)))),
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
                                shadows: const [Shadow(color: Colors.black87, blurRadius: 3)])))),
              ]),
            )));

        // الجسيمات
        for (final p in g.parts) {
          final o = (p.life / p.max).clamp(0.0, 1.0);
          if (p.text != null) {
            kids.add(Positioned(
                left: (p.x - cam) * t,
                top: p.y * t,
                child: Opacity(
                    opacity: o,
                    child: Text(p.text!,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: t * 0.45,
                            fontWeight: FontWeight.bold,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 3)])))));
          } else {
            kids.add(Positioned(
                left: (p.x - cam) * t,
                top: p.y * t,
                width: p.size * t,
                height: p.size * t,
                child: Opacity(
                    opacity: o,
                    child: DecoratedBox(
                        decoration: BoxDecoration(color: p.c, shape: BoxShape.circle)))));
          }
        }

        final sh = g.shake > 0
            ? Offset((rnd.nextDouble() - 0.5) * g.shake * 40, (rnd.nextDouble() - 0.5) * g.shake * 40)
            : Offset.zero;
        final world = Transform.translate(offset: sh, child: Stack(children: kids));

        // الواجهة
        final ui = <Widget>[];
        if (g.flash > 0) {
          ui.add(Positioned.fill(
              child: IgnorePointer(
                  child: ColoredBox(
                      color: Color.fromRGBO(255, 0, 0, (g.flash * 1.4).clamp(0.0, 0.5))))));
        }
        ui.add(Positioned(
            top: 8,
            left: 16,
            child: Text(
                '♥ ${g.lives}    ★ ${g.score}    ${g.sub == 2 ? "الزعيم" : "${g.world + 1}-${g.sub + 1}"}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)]))));
        if (b != null && !b.dead) {
          ui.add(Positioned(
              top: 12,
              left: c.maxWidth / 2 - 90,
              width: 180,
              height: 14,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (b.hp / b.maxHp).clamp(0.0, 1.0),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6)))))));
        }
        ui.add(Positioned(
            top: 2,
            right: 8,
            child: Row(children: [
              IconButton(
                  icon: Icon(Snd.on ? Icons.volume_up : Icons.volume_off, color: Colors.white),
                  onPressed: () {
                    Snd.on = !Snd.on;
                    if (Snd.on) {
                      Snd.music(g.world);
                    } else {
                      Snd.stopMusic();
                    }
                  }),
              IconButton(
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                  onPressed: () => setState(() => paused = !paused)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
            ])));
        if (g.bannerT > 0) {
          ui.add(Positioned(
              left: 0,
              right: 0,
              top: c.maxHeight * 0.3,
              child: IgnorePointer(
                  child: Opacity(
                      opacity: g.bannerT.clamp(0.0, 1.0),
                      child: Text(g.banner,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 6)]))))));
        }
        ui.add(Positioned(
            left: 20,
            bottom: 20,
            child: Row(children: [
              pad('◀', () => g.left = true, () => g.left = false, 76),
              const SizedBox(width: 16),
              pad('▶', () => g.right = true, () => g.right = false, 76),
            ])));
        ui.add(Positioned(
            right: 30, bottom: 20, child: pad('▲', () => g.jumpQueued = true, () {}, 90)));
        if (g.state == 'over' || g.state == 'win') {
          ui.add(Positioned.fill(
              child: Container(
                  color: Colors.black54,
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(g.state == 'win' ? 'أنقذت العوالم كلها! 🎉' : 'انتهت اللعبة',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                    Text('النقاط: ${g.score}',
                        style: const TextStyle(color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: () => setState(() {
                              g.restart();
                              musicWorld = -1;
                            }),
                        child: const Text('العب مجدداً')),
                  ])))));
        }
        return ClipRect(child: Stack(children: [world, ...ui]));
      }),
    );
  }
}
