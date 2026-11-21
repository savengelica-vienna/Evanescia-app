import 'dart:async';
import 'dart:math' show Random;
import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supaUrl = 'https://ypkvgvenejqfkacljtpa.supabase.co';
const supaKey = 'sb_publishable_P5FZe_rmoWEDO3rvjZAsYg_EPVYAiKR';

const bg = Color(0xFF0B0F1A);
const card = Color(0xFF121829);
const line = Color(0xFF222B45);
const mu = Color(0xFF7C88A8);
const ac = Color(0xFF6C7BFF);

final sb = Supabase.instance.client;

// Gelapkan background utama supaya teks tetap terbaca. 0 = tanpa lapisan gelap.
const kScrim = 0.28;

const rankOrder = ['user', 'member', 'premium', 'admin', 'helper', 'developer'];
int lv(String? r) {
  final i = rankOrder.indexOf(r ?? 'user');
  return i < 0 ? 0 : i;
}

const chatGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFD9FDD3), Color(0xFF25D366), Color(0xFFA7F3D0)],
);

String chatTime(String iso) {
  String two(int v) => v.toString().padLeft(2, '0');
  final t = DateTime.parse(iso).toLocal();
  final n = DateTime.now();
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    return '${two(t.hour)}:${two(t.minute)}';
  }
  final y = n.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) return 'Kemarin';
  return '${two(t.day)}/${two(t.month)}/${two(t.year % 100)}';
}

// ---------- BACKGROUND ANIMASI (oceanic) ----------
class _Pan extends GradientTransform {
  final double dx, dy;
  const _Pan(this.dx, this.dy);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx * bounds.width, dy * bounds.height, 0);
}

class OceanBg extends StatefulWidget {
  const OceanBg({super.key});
  @override
  State<OceanBg> createState() => _OceanBgState();
}

class _OceanBgState extends State<OceanBg> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  static const pts = [Offset(0, .5), Offset(.5, 1), Offset(1, .5), Offset(.5, 0), Offset(0, .5)];
  late final Animation<Offset> pos = TweenSequence<Offset>([
    for (var i = 0; i < 4; i++)
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: pts[i], end: pts[i + 1]).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
  ]).animate(c);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: pos,
          builder: (_, __) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -1),
                end: const Alignment(7, 7),
                colors: const [
                  Color(0xFF003B73),
                  Color(0xFF0077B6),
                  Color(0xFF00B4D8),
                  Color(0xFF48CAE4),
                  Color(0xFF90E0EF),
                  Color(0xFFCAF0F8),
                  Color(0xFF003B73),
                ],
                transform: _Pan(-pos.value.dx * 3, -pos.value.dy * 3),
              ),
            ),
          ),
        ),
      );
}

// ---------- LIQUID GLASS ala iOS ----------
// Lapisan: bayangan luar lembut -> blur latar -> isi tint tipis -> kilau atas
// -> garis tepi (rim light) yang terang di sudut kiri-atas & kanan-bawah.
class _ShadowPainter extends CustomPainter {
  final double radius;
  const _ShadowPainter(this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(-80, -80, size.width + 160, size.height + 160))
      ..addRRect(rr));
    canvas.drawRRect(
      rr.shift(const Offset(0, 8)),
      Paint()
        ..color = Colors.black.withOpacity(.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShadowPainter o) => o.radius != radius;
}

class _RimPainter extends CustomPainter {
  final double radius, width;
  const _RimPainter({required this.radius, this.width = 1.4});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(width / 2);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(.95),
            Colors.white.withOpacity(.10),
            Colors.white.withOpacity(.10),
            Colors.white.withOpacity(.65),
          ],
          stops: const [0, .38, .62, 1],
        ).createShader(rect),
    );
    // garis dalam tipis untuk kesan ketebalan kaca
    canvas.drawRRect(
      rr.deflate(width + .5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(.07),
    );
  }

  @override
  bool shouldRepaint(covariant _RimPainter o) => o.radius != radius || o.width != width;
}

class Glass extends StatelessWidget {
  final Widget child;
  final double radius, blur, strength;
  final Color tint;
  final EdgeInsetsGeometry padding;
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 14,
    this.strength = .46,
    this.tint = card,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return CustomPaint(
      painter: _ShadowPainter(radius),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: _RimPainter(radius: radius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tint.withOpacity(strength), tint.withOpacity(strength * .62)],
                ),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(.20), Colors.white.withOpacity(.03), Colors.white.withOpacity(0)],
                  stops: const [0, .35, .7],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Widget glassBox(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: Glass(radius: 26, padding: const EdgeInsets.all(18), child: child),
      ),
    );

class GlassButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final Color tint;
  final double strength;
  const GlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tint = ac,
    this.strength = .62,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Glass(
        radius: 40,
        blur: 10,
        tint: tint,
        strength: strength,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(40),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconTheme(data: const IconThemeData(color: Colors.white, size: 20), child: icon),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- NAV MENGAMBANG: bar kaca + lensa pembesar (RawMagnifier) ----------
class GlassNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const GlassNav({super.key, required this.index, required this.onTap});

  static const _icons = [Icons.home_outlined, Icons.chat_bubble_outline, Icons.person_outline];
  static const _fill = [Icons.home_rounded, Icons.chat_bubble_rounded, Icons.person_rounded];
  static const _labels = ['Home', 'Chat', 'Profile'];
  static const _barH = 68.0;
  static const _over = 5.0; // lensa lebih tinggi dari bar
  static const _side = 2.0; // dan sedikit lebih lebar dari slotnya

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    const lensH = _barH + _over * 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 12 + bottom),
      child: SizedBox(
        height: _barH,
        child: LayoutBuilder(builder: (context, c) {
          final slot = c.maxWidth / 3;
          final lensW = slot + _side * 2;
          return Stack(clipBehavior: Clip.none, children: [
            // 1) bar kaca
            const Positioned.fill(
              child: Glass(radius: 34, blur: 16, tint: Colors.white, strength: .16, child: SizedBox.expand()),
            ),
            // 2) ikon & label (di bawah lensa, jadi ikut diperbesar)
            Positioned.fill(
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(index == i ? _fill[i] : _icons[i],
                            size: 24, color: index == i ? Colors.white : Colors.white70),
                        const SizedBox(height: 2),
                        Text(_labels[i],
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: index == i ? Colors.white : Colors.white70)),
                      ]),
                    ),
                  ),
              ]),
            ),
            // 3) lensa liquid glass: memperbesar apa yang ada di bawahnya
            AnimatedPositioned(
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutBack,
              left: index * slot - _side,
              top: -_over,
              width: lensW,
              height: lensH,
              child: IgnorePointer(
                child: Stack(children: [
                  Positioned.fill(
                    child: RawMagnifier(
                      size: Size(lensW, lensH),
                      magnificationScale: 1.15,
                      focalPointOffset: Offset.zero,
                      decoration: MagnifierDecoration(
                        shape: const StadiumBorder(),
                        shadows: [
                          BoxShadow(color: Colors.black.withOpacity(.20), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      foregroundPainter: const _RimPainter(radius: lensH / 2, width: 1.8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(lensH / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(.26),
                              Colors.white.withOpacity(.05),
                              Colors.white.withOpacity(.12),
                            ],
                            stops: const [0, .5, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supaUrl, anonKey: supaKey);
  runApp(MaterialApp(
    title: 'NnevApp',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: ac, surface: card),
    ),
    home: const Gate(),
  ));
}

// ---------- RANK ----------
class Rk {
  final String name, desc;
  final IconData icon;
  final Color solid;
  final List<Color>? grad;
  final Color? glow;
  final bool anim;
  const Rk(this.name, this.desc, this.icon, this.solid,
      {this.grad, this.glow, this.anim = false});
}

const ranks = <String, Rk>{
  'user': Rk('User', 'User biasa', Icons.person_outline, Color(0xFF9CA3AF)),
  'member': Rk('Member', 'Member script', Icons.verified_user_outlined, Colors.white),
  'premium': Rk('Premium', 'Donatur script', Icons.diamond_outlined, Color(0xFFFFD700),
      grad: [Color(0xFFFFD700), Color(0xFFFFF4A3), Color(0xFFD4AF37), Color(0xFFFFD700)],
      glow: Color(0xFFFFD700)),
  'admin': Rk('Admin', 'Pengendali grup', Icons.workspace_premium_outlined, Color(0xFFFF4D8D),
      grad: [Color(0xFFFF1744), Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFF1744)],
      glow: Color(0xFFFF1493)),
  'helper': Rk('Helper', 'Staff', Icons.headset_mic_outlined, Color(0xFF00E5E5),
      grad: [Color(0xFF00FFFF), Color(0xFF00BFA5), Color(0xFF7FFFD4), Color(0xFF00FFFF)],
      glow: Color(0xFF00FFFF), anim: true),
  'developer': Rk('Developer', 'Maha raja dewa', Icons.code, Color(0xFFC06BFF),
      grad: [Color(0xFF9400FF), Color(0xFFDA70D6), Color(0xFFFFD700), Color(0xFF9400FF)],
      glow: Color(0xFF9400FF), anim: true),
};

class _Slide extends GradientTransform {
  final double p;
  const _Slide(this.p);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * p, 0, 0);
}

class RankText extends StatefulWidget {
  final String text, rank;
  final double size;
  const RankText(this.text, this.rank, {super.key, this.size = 17});
  @override
  State<RankText> createState() => _RankTextState();
}

class _RankTextState extends State<RankText> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  void _sync() {
    final a = ranks[widget.rank]?.anim ?? false;
    if (a && !c.isAnimating) c.repeat();
    if (!a) c.stop();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(RankText o) {
    super.didUpdateWidget(o);
    _sync();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ranks[widget.rank] ?? ranks['user']!;
    if (r.grad == null) {
      return Text(widget.text,
          style: TextStyle(fontSize: widget.size, fontWeight: FontWeight.w800, color: r.solid));
    }
    final style = TextStyle(
      fontSize: widget.size,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      shadows: [Shadow(color: r.glow!.withOpacity(.35), blurRadius: 4)],
    );
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (b) => LinearGradient(
          colors: r.grad!,
          tileMode: TileMode.repeated,
          transform: _Slide(c.value),
        ).createShader(b),
        child: Text(widget.text, style: style),
      ),
    );
  }
}

Widget box(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: child,
    );

Widget infoRow(IconData i, String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(i, size: 18, color: mu),
        const SizedBox(width: 8),
        Text(k, style: const TextStyle(color: mu, fontSize: 14)),
        const Spacer(),
        v,
      ]),
    );

// ---------- GATE + LOGIN ----------
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (_, __) =>
            sb.auth.currentSession == null ? const LoginPage() : const Home(),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final u = TextEditingController(), p = TextEditingController();
  String err = '';
  bool busy = false;

  Future<void> go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await sb.auth.signInWithPassword(
          email: '${u.text.trim().toLowerCase()}@nnevapp.local', password: p.text);
    } on AuthException {
      err = 'Username atau password salah';
    } catch (_) {
      err = 'Tidak bisa terhubung ke server';
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(TextEditingController c, String h, IconData i, {bool pw = false}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
        child: Row(children: [
          Icon(i, color: mu, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              obscureText: pw,
              autocorrect: false,
              decoration: InputDecoration(hintText: h, border: InputBorder.none),
              onSubmitted: (_) => pw ? go() : null,
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: const Icon(Icons.smartphone, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text('NnevApp', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Masuk dengan akun yang kamu punya', style: TextStyle(color: mu)),
                  const SizedBox(height: 26),
                  field(u, 'Username', Icons.person_outline),
                  field(p, 'Password', Icons.lock_outline, pw: true),
                  SizedBox(
                      height: 20,
                      child: Text(err, style: const TextStyle(color: Color(0xFFFF6B81), fontSize: 13))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: busy ? null : go,
                      icon: busy
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                          backgroundColor: ac,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

// ---------- HOME ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, cur = 0;
  int? shownFor;
  Map<String, dynamic>? cfg;
  StreamSubscription? sub;
  late final Stream<List<Map<String, dynamic>>> prof =
      sb.from('profiles').stream(primaryKey: ['id']).eq('id', sb.auth.currentUser!.id);

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      cur = int.tryParse(i.buildNumber) ?? 0;
      if (mounted) setState(() {});
      maybePrompt();
    });
    sub = sb.from('app_config').stream(primaryKey: ['id']).eq('id', 'android').listen((rows) {
      if (rows.isEmpty) return;
      cfg = rows.first;
      if (mounted) setState(() {});
      maybePrompt();
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  bool get hasUpdate =>
      cfg != null &&
      cur > 0 &&
      (cfg!['version_code'] as int) > cur &&
      (cfg!['apk_url'] ?? '').toString().isNotEmpty;

  void maybePrompt({bool force = false}) {
    if (!hasUpdate || !mounted) return;
    final vc = cfg!['version_code'] as int;
    if (!force && shownFor == vc) return;
    shownFor = vc;
    final must = cur < (cfg!['min_version_code'] as int);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(cfg: cfg!, force: must),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: prof,
        builder: (_, s) {
          final rows = s.data;
          if (rows == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (rows.isEmpty) {
            return Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Profil tidak ditemukan'),
                  TextButton(onPressed: () => sb.auth.signOut(), child: const Text('Keluar')),
                ]),
              ),
            );
          }
          final me = rows.first;
          final exp = me['expires_at'];
          if (exp != null && DateTime.parse(exp as String).isBefore(DateTime.now().toUtc())) {
            WidgetsBinding.instance.addPostFrameCallback((_) => sb.auth.signOut());
            return const Scaffold(body: Center(child: Text('Masa aktif akun kamu sudah habis')));
          }
          final updateTab = UpdatePage(
            cur: cur,
            cfg: cfg,
            onCheck: () {
              if (hasUpdate) {
                maybePrompt(force: true);
              } else {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Sudah versi terbaru')));
              }
            },
          );
          const pad = EdgeInsets.fromLTRB(18, 20, 18, 120);
          return Stack(children: [
            const Positioned.fill(child: OceanBg()),
            Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(kScrim))),
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: SafeArea(
                bottom: false,
                child: IndexedStack(index: tab, children: [
                  ListView(padding: pad, physics: const BouncingScrollPhysics(), children: [updateTab]),
                  ChatListPage(me: me),
                  ListView(padding: pad, physics: const BouncingScrollPhysics(), children: [ProfilePage(me: me)]),
                ]),
              ),
              bottomNavigationBar: GlassNav(index: tab, onTap: (i) => setState(() => tab = i)),
            ),
          ]);
        },
      );
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> me;
  const ProfilePage({super.key, required this.me});
  @override
  Widget build(BuildContext context) {
    final rank = me['rank'] as String;
    final r = ranks[rank] ?? ranks['user']!;
    final name = me['username'] as String;
    return Column(children: [
      glassBox(Column(children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => changeMyAvatar(context),
          child: SizedBox(
            width: 92,
            height: 92,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  width: 84,
                  height: 84,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: bg, border: Border.all(color: line, width: 2)),
                  child: (me['avatar_url'] is String && (me['avatar_url'] as String).isNotEmpty)
                      ? Image.network(me['avatar_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(r.icon, size: 38, color: r.solid))
                      : Icon(r.icon, size: 38, color: r.solid),
                ),
              ),
              Positioned(right: 0, bottom: 0, child: camBadge()),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        RankText(name, rank, size: 28),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => showRankList(context),
          child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.icon, size: 16, color: r.solid),
            const SizedBox(width: 6),
            RankText(r.name, rank, size: 13),
          ]),
        )),
        const SizedBox(height: 8),
      ])),
      glassBox(Column(children: [
        infoRow(Icons.badge_outlined, 'Username', Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
        InkWell(
          onTap: () => showRankList(context),
          child: infoRow(r.icon, 'Rank', Row(mainAxisSize: MainAxisSize.min, children: [
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right, size: 18, color: mu),
          ])),
        ),
        infoRow(Icons.timer_outlined, 'Masa aktif',
            Text(me['expires_at'] == null ? 'Lifetime' : (me['expires_at'] as String).substring(0, 10),
                style: const TextStyle(fontWeight: FontWeight.w700))),
        infoRow(Icons.calendar_today_outlined, 'Bergabung',
            Text((me['created_at'] as String).substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700))),
      ])),
      if (rank == 'developer' || rank == 'helper') ...[
        SizedBox(
          width: double.infinity,
          height: 48,
          child: GlassButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageUsersPage(myRank: rank))),
            icon: const Icon(Icons.group_add_outlined),
            label: 'Kelola User',
          ),
        ),
        const SizedBox(height: 10),
      ],
      SizedBox(
        width: double.infinity,
        height: 48,
        child: GlassButton(
          tint: Colors.white,
          strength: .16,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Keluar dari akun?'),
                content: const Text('Kamu harus login lagi untuk masuk.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D)),
                    child: const Text('Ya, keluar'),
                  ),
                ],
              ),
            );
            if (ok == true) sb.auth.signOut();
          },
          icon: const Icon(Icons.logout),
          label: 'Keluar',
        ),
      ),
    ]);
  }
}

class RankPage extends StatelessWidget {
  const RankPage({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daftar Rank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        box(Column(
          children: ranks.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Icon(e.value.icon, color: e.value.solid),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RankText(e.value.name, e.key),
                        Text(e.value.desc, style: const TextStyle(color: mu, fontSize: 12)),
                      ]),
                    ]),
                  ))
              .toList(),
        )),
      ]);
}

class UpdatePage extends StatelessWidget {
  final int cur;
  final Map<String, dynamic>? cfg;
  final VoidCallback onCheck;
  const UpdatePage({super.key, required this.cur, required this.cfg, required this.onCheck});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        glassBox(Column(children: [
          infoRow(Icons.sell_outlined, 'Build terpasang', Text('$cur', style: const TextStyle(fontWeight: FontWeight.w700))),
          infoRow(Icons.refresh, 'Versi terbaru',
              Text(cfg == null ? '-' : '${cfg!['version_name']} (${cfg!['version_code']})',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ])),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: GlassButton(
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: 'Cek update',
          ),
        ),
      ]);
}

// ---------- UPDATE DIALOG (download otomatis) ----------
class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> cfg;
  final bool force;
  const UpdateDialog({super.key, required this.cfg, required this.force});
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double pct = 0;
  String msg = 'Mengunduh...';
  bool err = false;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final req = http.Request('GET', Uri.parse(widget.cfg['apk_url'] as String));
      final res = await http.Client().send(req);
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nnevapp.apk');
      final sink = file.openWrite();
      final total = res.contentLength ?? 0;
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && mounted) {
          setState(() {
            pct = got / total;
            msg = 'Mengunduh ${(pct * 100).toInt()}%';
          });
        }
      }
      await sink.close();
      if (!mounted) return;
      setState(() {
        pct = 1;
        msg = 'Membuka installer...';
      });
      final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (r.type != ResultType.done && mounted) {
        setState(() {
          err = true;
          msg = 'Izinkan install dari sumber ini, lalu coba lagi';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          err = true;
          msg = 'Gagal mengunduh';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
                ),
                child: const Icon(Icons.download, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(widget.force ? 'Update Wajib' : 'Update Tersedia',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Versi ${widget.cfg['version_name']}\n${widget.cfg['changelog'] ?? ''}',
                  textAlign: TextAlign.center, style: const TextStyle(color: mu)),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: err ? 0 : pct, minHeight: 8, backgroundColor: bg),
              ),
              const SizedBox(height: 10),
              Text(msg, style: const TextStyle(color: mu, fontSize: 13)),
              const SizedBox(height: 14),
              if (err)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() {
                      err = false;
                      pct = 0;
                      msg = 'Mengunduh...';
                      start();
                    }),
                    child: const Text('Coba lagi'),
                  ),
                ),
              if (!widget.force)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            ]),
          ),
        ),
      );
}

// ---------- HELPER ----------
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

void showRankList(BuildContext c) => showModalBottomSheet(
      context: c,
      backgroundColor: bg,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(18),
        child: SingleChildScrollView(child: RankPage()),
      ),
    );

Widget avatar(String rank, {double s = 34, String? url}) {
  final r = ranks[rank] ?? ranks['user']!;
  final fallback = Icon(r.icon, size: s * .5, color: r.solid);
  return Container(
    width: s,
    height: s,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(shape: BoxShape.circle, color: card, border: Border.all(color: line)),
    child: (url == null || url.isEmpty)
        ? fallback
        : Image.network(url,
            fit: BoxFit.cover, width: s, height: s, errorBuilder: (_, __, ___) => Center(child: fallback)),
  );
}

// ---------- CHAT ----------
String dmRoom(String a, String b) => a.compareTo(b) < 0 ? 'dm_${a}_$b' : 'dm_${b}_$a';

String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-'
      '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class ChatListPage extends StatefulWidget {
  final Map<String, dynamic> me;
  const ChatListPage({super.key, required this.me});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> users = [], msgs = [], hides = [];
  final subs = <StreamSubscription>[];
  final acked = <String>{};
  int seg = 0;

  @override
  void initState() {
    super.initState();
    subs.add(sb.from('profiles').stream(primaryKey: ['id']).listen((r) {
      if (mounted) setState(() => users = r);
    }));
    subs.add(sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(300)
        .listen((r) {
      if (mounted) setState(() => msgs = r);
      _ack(r);
    }));
    subs.add(sb.from('message_hides').stream(primaryKey: ['message_id', 'user_id']).listen((r) {
      if (mounted) setState(() => hides = r);
    }));
  }

  @override
  void dispose() {
    for (final x in subs) {
      x.cancel();
    }
    super.dispose();
  }

  // Tandai pesan orang lain sebagai "sampai" (centang dua abu-abu)
  Future<void> _ack(List<Map<String, dynamic>> r) async {
    final me = sb.auth.currentUser!.id;
    final ids = [
      for (final m in r)
        if (m['user_id'] != me && !acked.contains(m['id'])) m['id'] as String
    ];
    if (ids.isEmpty) return;
    acked.addAll(ids);
    try {
      await sb.from('message_receipts').upsert(
        [for (final id in ids) {'message_id': id}],
        onConflict: 'message_id,user_id',
        ignoreDuplicates: true,
      );
    } catch (_) {
      acked.removeAll(ids);
    }
  }

  Widget segBar() => Glass(
        radius: 26,
        blur: 12,
        strength: .30,
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          for (final e in const [(0, 'Grup', Icons.groups_outlined), (1, 'User', Icons.person_outline)])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => seg = e.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: seg == e.$1 ? Colors.white.withOpacity(.22) : Colors.transparent,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(e.$3, size: 18, color: seg == e.$1 ? Colors.white : Colors.white70),
                    const SizedBox(width: 6),
                    Text(e.$2,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: seg == e.$1 ? Colors.white : Colors.white70)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  void open(Map<String, dynamic>? peer) => Navigator.push(
      context, CupertinoPageRoute(builder: (_) => ChatRoomPage(me: widget.me, peer: peer)));

  Widget convRow({
    required Widget leading,
    required Widget title,
    required String preview,
    String? time,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: title),
                  if (time != null) Text(time, style: const TextStyle(color: mu, fontSize: 12)),
                ]),
                const SizedBox(height: 3),
                Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: mu, fontSize: 14)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final myId = sb.auth.currentUser!.id;
    final hid = {for (final h in hides) h['message_id'] as String};
    final profs = {for (final p in users) p['id'] as String: p};

    Map<String, dynamic>? lastOf(String room) {
      for (final m in msgs) {
        if (m['room'] == room && !hid.contains(m['id'])) return m;
      }
      return null;
    }

    String who(Map<String, dynamic> m) =>
        m['user_id'] == myId ? 'Kamu' : ((profs[m['user_id']]?['username'] ?? '?') as String);

    final entries = users
        .where((u) => u['id'] != myId)
        .map((u) => MapEntry(u, lastOf(dmRoom(myId, u['id'] as String))))
        .toList();
    entries.sort((a, b) {
      final x = a.value, y = b.value;
      if (x != null && y != null) return (y['created_at'] as String).compareTo(x['created_at'] as String);
      if (x != null) return -1;
      if (y != null) return 1;
      return (a.key['username'] as String).toLowerCase().compareTo((b.key['username'] as String).toLowerCase());
    });

    final g = lastOf('main');
    final groupItems = <Widget>[
      convRow(
        leading: const GroupAvatar(s: 52),
        title: const Text('Chat Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        preview: g == null
            ? 'Belum ada pesan'
            : (g['deleted_at'] != null
                ? (g['user_id'] == myId ? 'Kamu menghapus pesan ini' : 'Pesan ini telah dihapus')
                : '${who(g)}: ${g['body']}'),
        time: g == null ? null : chatTime(g['created_at'] as String),
        onTap: () => open(null),
      ),
    ];
    final userItems = <Widget>[
      for (final e in entries)
        convRow(
          leading: avatar((e.key['rank'] ?? 'user') as String, s: 52, url: e.key['avatar_url'] as String?),
          title: Row(children: [
            Flexible(child: RankText(e.key['username'] as String, (e.key['rank'] ?? 'user') as String, size: 16)),
            const SizedBox(width: 6),
            RankText('(${(ranks[e.key['rank']] ?? ranks['user']!).name})', (e.key['rank'] ?? 'user') as String,
                size: 12),
          ]),
          preview: e.value == null
              ? 'Ketuk untuk mulai chat'
              : (e.value!['deleted_at'] != null
                  ? (e.value!['user_id'] == myId ? 'Kamu menghapus pesan ini' : 'Pesan ini telah dihapus')
                  : (e.value!['user_id'] == myId ? 'Kamu: ' : '') + (e.value!['body'] as String)),
          time: e.value == null ? null : chatTime(e.value!['created_at'] as String),
          onTap: () => open(e.key),
        ),
    ];
    final items = seg == 0 ? groupItems : userItems;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
      children: [
        const Text('Chat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        segBar(),
        const SizedBox(height: 12),
        Glass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: line, indent: 66),
              items[i],
            ],
          ]),
        ),
        if (seg == 1 && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Belum ada user lain', style: TextStyle(color: Colors.white70))),
          ),
      ],
    );
  }
}

class ChatRoomPage extends StatefulWidget {
  final Map<String, dynamic> me;
  final Map<String, dynamic>? peer; // null = Chat Utama (grup)
  const ChatRoomPage({super.key, required this.me, this.peer});
  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ctl = TextEditingController();
  late final String room = widget.peer == null
      ? 'main'
      : dmRoom(sb.auth.currentUser!.id, widget.peer!['id'] as String);
  List<Map<String, dynamic>> msgs = [], reacts = [], vis = [];
  Map<String, Map<String, dynamic>> profs = {};
  Set<String> hidden = {};
  Set<String> stars = {};
  Set<String> gone = {};
  Set<String> tomb = {};
  Map<String, int> rstat = {};
  final pending = <Map<String, dynamic>>[];
  final readSent = <String>{};
  Map<String, dynamic>? replyTo;
  final focus = FocusNode();
  final seen = <String>{};
  bool loaded = false;
  final subs = <StreamSubscription>[];

  bool get isGroup => widget.peer == null;
  int get myLv => lv((profs[sb.auth.currentUser!.id]?['rank'] ?? widget.me['rank']) as String?);
  String nameOf(Map<String, dynamic> m) => (profs[m['user_id']]?['username'] ?? '?') as String;

  @override
  void initState() {
    super.initState();
    subs.add(sb.from('profiles').stream(primaryKey: ['id']).listen((r) {
      if (mounted) setState(() => profs = {for (final p in r) p['id'] as String: p});
    }));
    subs.add(sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room', room)
        .order('created_at', ascending: false)
        .limit(100)
        .listen((r) {
      if (!loaded) {
        seen.addAll(r.map((m) => m['id'] as String));
        loaded = true;
      }
      if (mounted) {
        setState(() {
          msgs = r;
          pending.removeWhere((p) => r.any((m) => m['id'] == p['id']));
        });
        _markRead(r);
      }
    }));
    subs.add(sb.from('reactions').stream(primaryKey: ['message_id', 'user_id']).listen((r) {
      if (mounted) setState(() => reacts = r);
    }));
    subs.add(sb
        .from('message_receipts')
        .stream(primaryKey: ['message_id', 'user_id'])
        .order('delivered_at', ascending: false)
        .limit(600)
        .listen((r) {
      final me = sb.auth.currentUser!.id;
      final out = <String, int>{};
      for (final x in r) {
        if (x['user_id'] == me) continue;
        final lvl = x['read_at'] != null ? 2 : 1;
        final k = x['message_id'] as String;
        if ((out[k] ?? 0) < lvl) out[k] = lvl;
      }
      if (mounted) setState(() => rstat = out);
    }, onError: (_) {}));
    subs.add(sb.from('message_hides').stream(primaryKey: ['message_id', 'user_id']).listen((r) {
      if (mounted) setState(() => hidden = {for (final h in r) h['message_id'] as String});
    }));
    subs.add(sb.from('message_stars').stream(primaryKey: ['message_id', 'user_id']).listen((r) {
      final me = sb.auth.currentUser!.id;
      if (mounted) {
        setState(() => stars = {
              for (final x in r)
                if (x['user_id'] == me) x['message_id'] as String
            });
      }
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final x in subs) {
      x.cancel();
    }
    ctl.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    ctl.clear();
    final rt = replyTo;
    final p = <String, dynamic>{
      'id': newId(),
      'user_id': sb.auth.currentUser!.id,
      'body': t,
      'room': room,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reply_to': rt?['id'],
      '_st': 'sending',
    };
    setState(() {
      replyTo = null;
      pending.add(p);
    });
    await _dosend(p);
  }

  Future<void> _dosend(Map<String, dynamic> p) async {
    final data = <String, dynamic>{'id': p['id'], 'body': p['body'], 'room': p['room']};
    if (p['reply_to'] != null) data['reply_to'] = p['reply_to'];
    try {
      await sb.from('messages').insert(data);
      if (mounted) setState(() => p['_st'] = 'sent');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) setState(() => p['_st'] = 'sent');
      } else if (mounted) {
        setState(() => p['_st'] = 'failed');
        snack(context, 'Gagal mengirim. Ketuk pesan untuk kirim ulang');
      }
    } catch (_) {
      if (mounted) {
        setState(() => p['_st'] = 'failed');
        snack(context, 'Gagal mengirim. Ketuk pesan untuk kirim ulang');
      }
    }
  }

  void retry(Map<String, dynamic> p) {
    setState(() => p['_st'] = 'sending');
    _dosend(p);
  }

  Future<void> _markRead(List<Map<String, dynamic>> r) async {
    final me = sb.auth.currentUser!.id;
    final ids = [
      for (final m in r)
        if (m['user_id'] != me && !readSent.contains(m['id'])) m['id'] as String
    ];
    if (ids.isEmpty) return;
    readSent.addAll(ids);
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await sb.from('message_receipts').upsert(
        [for (final id in ids) {'message_id': id, 'read_at': now}],
        onConflict: 'message_id,user_id',
      );
    } catch (_) {
      readSent.removeAll(ids);
    }
  }

  Widget tick(Map<String, dynamic> m) {
    final st = m['_st'];
    if (st == 'sending') return const Icon(Icons.schedule, size: 13, color: Colors.white70);
    if (st == 'failed') return const Icon(Icons.error_outline, size: 14, color: Color(0xFFFF6B81));
    final lvl = rstat[m['id']] ?? 0;
    if (lvl >= 2) return const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB));
    if (lvl == 1) return const Icon(Icons.done_all, size: 15, color: Colors.white70);
    return const Icon(Icons.check, size: 14, color: Colors.white70);
  }

  Future<void> react(String mid, String emoji) async {
    final uid = sb.auth.currentUser!.id;
    final mine = reacts.where((x) => x['message_id'] == mid && x['user_id'] == uid).toList();
    try {
      if (mine.isEmpty) {
        await sb.from('reactions').insert({'message_id': mid, 'emoji': emoji});
      } else if (mine.first['emoji'] == emoji) {
        await sb.from('reactions').delete().match({'message_id': mid, 'user_id': uid});
      } else {
        await sb.from('reactions').update({'emoji': emoji}).match({'message_id': mid, 'user_id': uid});
      }
    } catch (_) {}
  }

  Future<void> hideForMe(String id) async {
    setState(() => gone.add(id)); // langsung hilang, tidak menunggu server
    try {
      await sb.from('message_hides').insert({'message_id': id});
    } catch (_) {
      if (mounted) {
        setState(() => gone.remove(id));
        snack(context, 'Gagal menghapus pesan');
      }
    }
  }

  bool isDel(Map<String, dynamic> m) => m['deleted_at'] != null || tomb.contains(m['id']);

  Widget tombstone(bool mine) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.block, size: 15, color: Colors.white54),
        const SizedBox(width: 6),
        Flexible(
          child: Text(mine ? 'Kamu menghapus pesan ini' : 'Pesan ini telah dihapus',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white60)),
        ),
      ]);

  void delSheet(String id) => showModalBottomSheet(
        context: context,
        backgroundColor: card,
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B81)),
            title: const Text('Hapus untuk saya'),
            onTap: () {
              Navigator.pop(ctx);
              hideForMe(id);
            },
          ),
        ),
      );

  Future<void> deleteAll(String id) async {
    setState(() => tomb.add(id)); // langsung berubah jadi "Kamu menghapus pesan ini"
    try {
      await sb.rpc('delete_message', params: {'p_id': id});
    } catch (_) {
      if (mounted) {
        setState(() => tomb.remove(id));
        snack(context, 'Gagal menghapus pesan');
      }
    }
  }

  Future<void> pin(String id, bool v) async {
    try {
      await sb.rpc('pin_message', params: {'p_id': id, 'p_pin': v});
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    } catch (_) {
      if (mounted) snack(context, 'Gagal menyematkan pesan');
    }
  }

  void _hideKb() {
    focus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void openProfile(Map<String, dynamic>? p) {
    if (p == null) return;
    _hideKb();
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => UserProfilePage(me: widget.me, user: p, fromRoom: room)));
  }

  Future<void> star(String id) async {
    final uid = sb.auth.currentUser!.id;
    try {
      if (stars.contains(id)) {
        await sb.from('message_stars').delete().match({'message_id': id, 'user_id': uid});
      } else {
        await sb.from('message_stars').insert({'message_id': id});
      }
    } catch (_) {
      if (mounted) snack(context, 'Gagal memberi bintang');
    }
  }

  void forward(Map<String, dynamic> m) {
    final myId = sb.auth.currentUser!.id;
    final targets = <MapEntry<String, String>>[
      const MapEntry('main', 'Chat Utama'),
      for (final p in profs.values)
        if (p['id'] != myId) MapEntry(dmRoom(myId, p['id'] as String), p['username'] as String),
    ];
    final sel = <String>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Teruskan ke', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final t in targets)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: sel.contains(t.key),
                      title: Text(t.value),
                      onChanged: (v) => set(() {
                        if (v == true) {
                          sel.add(t.key);
                        } else {
                          sel.remove(t.key);
                        }
                      }),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: GlassButton(
                  icon: const Icon(Icons.send),
                  label: sel.isEmpty ? 'Pilih tujuan' : 'Kirim (${sel.length})',
                  onPressed: sel.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            for (final r in sel) {
                              await sb.from('messages').insert({'body': m['body'], 'room': r, 'forwarded': true});
                            }
                            if (mounted) snack(context, 'Pesan diteruskan');
                          } catch (_) {
                            if (mounted) snack(context, 'Gagal meneruskan pesan');
                          }
                        },
                ),
              ),
            ]),
          ),
        ),
      ),
    ).whenComplete(_hideKb);
  }

  Future<void> pick(Map<String, dynamic> m, bool mine, Rect rect, Widget bodyW) async {
    final id = m['id'] as String;
    final canPin = isGroup && myLv >= 2;
    final pinned = m['pinned_at'] != null;
    final uid = sb.auth.currentUser!.id;
    String? myEmoji;
    for (final x in reacts) {
      if (x['message_id'] == id && x['user_id'] == uid) myEmoji = x['emoji'] as String?;
    }
    _hideKb();
    await showMsgMenu(
      context: context,
      rect: rect,
      mine: mine,
      bubble: bodyW,
      myEmoji: myEmoji,
      starred: stars.contains(id),
      canPin: canPin,
      pinned: pinned,
      onReact: (e) => react(id, e),
      onMore: () async {
        final e = await showEmojiSheet(context);
        if (e != null) react(id, e);
        _hideKb();
      },
      onReply: () => setState(() => replyTo = m),
      onForward: () => forward(m),
      onCopy: () {
        Clipboard.setData(ClipboardData(text: m['body'] as String));
        snack(context, 'Pesan disalin');
      },
      onStar: () => star(id),
      onPin: () => pin(id, !pinned),
      onDeleteMe: () => hideForMe(id),
      onDeleteAll: mine ? () => deleteAll(id) : null,
    );
    _hideKb();
  }

  void showPinned(List<Map<String, dynamic>> pins) => showModalBottomSheet(
        context: context,
        backgroundColor: card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pesan disematkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final m in pins)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.push_pin, color: ac, size: 20),
                      title: Text(nameOf(m), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(m['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: myLv >= 2
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18, color: mu),
                              onPressed: () {
                                Navigator.pop(ctx);
                                pin(m['id'] as String, false);
                              },
                            )
                          : null,
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget bubble(int i, String uid) {
    final m = vis[i];
    final sid = m['user_id'] as String;
    final mine = sid == uid;
    final p = profs[sid];
    final rank = (p?['rank'] ?? 'user') as String;
    final name = (p?['username'] ?? '?') as String;
    final first = i == vis.length - 1 || vis[i + 1]['user_id'] != sid;
    final t = DateTime.parse(m['created_at'] as String).toLocal();
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final id = m['id'] as String;
    final del = isDel(m);
    final pinned = m['pinned_at'] != null;
    final counts = <String, int>{};
    String? my;
    for (final x in reacts.where((x) => x['message_id'] == id)) {
      final e = x['emoji'] as String;
      counts[e] = (counts[e] ?? 0) + 1;
      if (x['user_id'] == uid) my = e;
    }
    final isNew = loaded && !seen.contains(id);
    seen.add(id);
    const big = Radius.circular(16), small = Radius.circular(4);
    final bodyW = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF144D37) : card,
        borderRadius: BorderRadius.only(
          topLeft: (!mine && first) ? small : big,
          topRight: (mine && first) ? small : big,
          bottomLeft: big,
          bottomRight: big,
        ),
        border: Border.all(color: mine ? Colors.transparent : line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!mine && first) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            RankText(name, rank, size: 13),
            const SizedBox(width: 5),
            RankText('(${(ranks[rank] ?? ranks['user']!).name})', rank, size: 10),
          ]),
          const SizedBox(height: 2),
        ],
        if (!del && m['forwarded'] == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shortcut, size: 12, color: mu),
              SizedBox(width: 4),
              Text('Diteruskan', style: TextStyle(color: mu, fontSize: 11, fontStyle: FontStyle.italic)),
            ]),
          ),
        if (!del && m['reply_to'] != null) quote(m['reply_to'] as String),
        del ? tombstone(mine) : Text(m['body'] as String, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (stars.contains(id)) ...[
              const Icon(Icons.star, size: 11, color: Color(0xFFFFD54F)),
              const SizedBox(width: 3),
            ],
            if (pinned) ...[const Icon(Icons.push_pin, size: 10, color: mu), const SizedBox(width: 3)],
            Text(time, style: const TextStyle(color: mu, fontSize: 10)),
            if (mine && !del) ...[const SizedBox(width: 3), tick(m)],
          ]),
        ),
      ]),
    );
    final content = Builder(
      builder: (bctx) => GestureDetector(
        onTap: m['_st'] == 'failed' ? () => retry(m) : null,
        onLongPress: () {
          if (m['_st'] != null) return;
          if (del) {
            delSheet(id);
            return;
          }
          final rb = bctx.findRenderObject() as RenderBox;
          final off = rb.localToGlobal(Offset.zero);
          pick(m, mine, off & rb.size, bodyW);
        },
        child: bodyW,
      ),
    );
    final chips = (counts.isEmpty || del)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              spacing: 4,
              children: counts.entries
                  .map((e) => GestureDetector(
                        onTap: () => react(id, e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: e.key == my ? ac.withOpacity(.25) : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: e.key == my ? ac : line),
                          ),
                          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
            ),
          );
    final col = Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [content, chips],
    );
    final row = Padding(
      padding: EdgeInsets.only(top: first ? 10 : 2),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [col]
            : [
                first
                    ? GestureDetector(
                        onTap: () => openProfile(p),
                        child: avatar(rank, url: p?['avatar_url'] as String?))
                    : const SizedBox(width: 34),
                const SizedBox(width: 6),
                col
              ],
      ),
    );
    return TweenAnimationBuilder<double>(
      key: ValueKey(id),
      tween: Tween<double>(begin: isNew ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset((mine ? 24 : -24) * (1 - v), 14 * (1 - v)), child: child),
      ),
      child: row,
    );
  }

  Widget quote(String rid) {
    Map<String, dynamic>? r;
    for (final x in msgs) {
      if (x['id'] == rid) {
        r = x;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black.withOpacity(.22),
          child: IntrinsicHeight(
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 3, color: ac),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(r == null ? 'Pesan' : nameOf(r),
                        style: const TextStyle(color: ac, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(r == null ? 'Pesan tidak tersedia' : (r['deleted_at'] != null ? 'Pesan ini telah dihapus' : r['body'] as String),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget replyBar() {
    final r = replyTo!;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      decoration: BoxDecoration(
        color: card.withOpacity(.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: ac),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Membalas ${nameOf(r)}',
                      style: const TextStyle(color: ac, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(r['body'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ]),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => replyTo = null),
              icon: const Icon(Icons.close, size: 18, color: mu),
            ),
          ]),
        ),
      ),
    );
  }

  Widget pinBanner(List<Map<String, dynamic>> pins) => GestureDetector(
        onTap: () => showPinned(pins),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: card.withOpacity(.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: Row(children: [
            const Icon(Icons.push_pin, size: 16, color: ac),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${nameOf(pins.first)}: ${pins.first['body']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            if (pins.length > 1) Text('+${pins.length - 1}', style: const TextStyle(color: mu, fontSize: 12)),
          ]),
        ),
      );

  Widget inputBar() => Container(
        margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: card.withOpacity(.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: ctl,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: const InputDecoration(
                hintText: 'Tulis pesan...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
            ),
            child: IconButton(onPressed: send, icon: const Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final uid = sb.auth.currentUser!.id;
    final msgIds = {for (final m in msgs) m['id']};
    vis = [
      ...pending.reversed.where((p) => !msgIds.contains(p['id']) && !gone.contains(p['id'])),
      ...msgs.where((m) => !hidden.contains(m['id']) && !gone.contains(m['id'])),
    ];
    final pins = isGroup
        ? (vis.where((m) => m['pinned_at'] != null).toList()
          ..sort((a, b) => (b['pinned_at'] as String).compareTo(a['pinned_at'] as String)))
        : <Map<String, dynamic>>[];
    final peer = widget.peer;
    final prk = (peer?['rank'] ?? 'user') as String;
    final Map<String, dynamic>? pp = peer == null ? null : (profs[peer['id']] ?? peer);
    return Container(
      decoration: const BoxDecoration(gradient: chatGrad),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: card,
          scrolledUnderElevation: 0,
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: peer == null
                ? () {
                    _hideKb();
                    Navigator.push(
                        context, CupertinoPageRoute(builder: (_) => GroupProfilePage(me: widget.me)));
                  }
                : () => openProfile(pp),
            child: peer == null
                ? const Row(children: [
                    GroupAvatar(s: 32),
                    SizedBox(width: 10),
                    Text('Chat Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ])
                : Row(children: [
                    avatar(prk, s: 32, url: pp?['avatar_url'] as String?),
                    const SizedBox(width: 10),
                    RankText(peer['username'] as String, prk, size: 16),
                    const SizedBox(width: 6),
                    RankText('(${(ranks[prk] ?? ranks['user']!).name})', prk, size: 12),
                  ]),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            if (pins.isNotEmpty) pinBanner(pins),
            Expanded(
              child: vis.isEmpty
                  ? const Center(
                      child: Text('Belum ada pesan. Mulai obrolan!',
                          style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.w600)))
                  : ListView.builder(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: vis.length,
                      itemBuilder: (_, i) => bubble(i, uid),
                    ),
            ),
            if (replyTo != null) replyBar(),
            inputBar(),
          ]),
        ),
      ),
    );
  }
}

// ---------- KELOLA USER (Developer & Helper) ----------
class DurationPicker extends StatefulWidget {
  final bool allowKeep;
  final ValueChanged<int?> onChanged; // null = lifetime, -1 = tidak diubah / belum diisi
  const DurationPicker({super.key, required this.onChanged, this.allowKeep = false});
  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late String sel = widget.allowKeep ? 'keep' : 'life';
  final c = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onChanged(widget.allowKeep ? -1 : null);
  }

  Widget opt(String key, String label, int? d) => ChoiceChip(
        label: Text(label),
        selected: sel == key,
        onSelected: (_) {
          setState(() => sel = key);
          widget.onChanged(d);
        },
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, children: [
          if (widget.allowKeep) opt('keep', 'Tetap', -1),
          opt('life', 'Lifetime', null),
          opt('7', '7 hari', 7),
          opt('30', '30 hari', 30),
          opt('90', '90 hari', 90),
          ChoiceChip(
            label: const Text('Custom'),
            selected: sel == 'custom',
            onSelected: (_) {
              setState(() => sel = 'custom');
              widget.onChanged(int.tryParse(c.text) ?? -1);
            },
          ),
        ]),
        if (sel == 'custom')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah hari', border: OutlineInputBorder()),
              onChanged: (v) => widget.onChanged(int.tryParse(v) ?? -1),
            ),
          ),
      ]);
}

class ManageUsersPage extends StatefulWidget {
  final String myRank;
  const ManageUsersPage({super.key, required this.myRank});
  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final un = TextEditingController(), pw = TextEditingController();
  String rank = 'user';
  int? days;
  bool busy = false;
  List<Map<String, dynamic>> users = [];
  StreamSubscription? sub;

  int get myLv => lv(widget.myRank);
  String get myId => sb.auth.currentUser!.id;
  List<String> get assignable => ranks.keys.where((k) => myLv >= 5 || lv(k) < myLv).toList();
  bool canManage(Map<String, dynamic> u) =>
      u['id'] != myId && (myLv >= 5 || lv(u['rank'] as String?) < myLv);

  @override
  void initState() {
    super.initState();
    sub = sb.from('profiles').stream(primaryKey: ['id']).order('created_at').listen((r) {
      if (mounted) setState(() => users = r);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> create() async {
    if (days == -1) {
      snack(context, 'Isi jumlah hari dulu');
      return;
    }
    setState(() => busy = true);
    try {
      await sb.rpc('create_user', params: {
        'p_username': un.text.trim(),
        'p_password': pw.text,
        'p_rank': rank,
        'p_days': days,
      });
      un.clear();
      pw.clear();
      if (mounted) snack(context, 'Akun berhasil dibuat');
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    } catch (_) {
      if (mounted) snack(context, 'Gagal membuat akun');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> del(Map<String, dynamic> u) async {
    if (!canManage(u)) {
      snack(context, 'Rank kamu tidak cukup untuk menghapus user ini');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus ${u['username']}?'),
        content: const Text('Akun dan semua pesannya akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.rpc('delete_user', params: {'p_id': u['id']});
      if (mounted) snack(context, 'User dihapus');
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    } catch (_) {
      if (mounted) snack(context, 'Gagal menghapus user');
    }
  }

  Widget rankChips(String sel, void Function(String) on) => Wrap(
        spacing: 6,
        children: ranks.entries
            .where((e) => assignable.contains(e.key))
            .map((e) => ChoiceChip(
                  avatar: Icon(e.value.icon, size: 16, color: e.value.solid),
                  label: Text(e.value.name),
                  selected: sel == e.key,
                  onSelected: (_) => on(e.key),
                ))
            .toList(),
      );

  void edit(Map<String, dynamic> u) {
    if (!canManage(u)) {
      snack(context, 'Rank kamu tidak cukup untuk mengelola user ini');
      return;
    }
    var r = u['rank'] as String;
    int? d = -1;
    final pc = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['username'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text('Rank', style: TextStyle(color: mu)),
              const SizedBox(height: 6),
              rankChips(r, (v) => ss(() => r = v)),
              const SizedBox(height: 14),
              const Text('Masa aktif', style: TextStyle(color: mu)),
              const SizedBox(height: 6),
              DurationPicker(allowKeep: true, onChanged: (v) => d = v),
              const SizedBox(height: 14),
              TextField(
                controller: pc,
                decoration: const InputDecoration(
                    labelText: 'Password baru (kosongkan jika tidak diubah)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      del(u);
                    },
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B81)),
                    label: const Text('Hapus', style: TextStyle(color: Color(0xFFFF6B81))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await sb.rpc('update_user', params: {
                          'p_id': u['id'],
                          'p_rank': r,
                          'p_set_expiry': d != -1,
                          'p_days': d == -1 ? null : d,
                        });
                        if (pc.text.isNotEmpty) {
                          await sb.rpc('set_user_password', params: {'p_id': u['id'], 'p_password': pc.text});
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } on PostgrestException catch (e) {
                        if (ctx.mounted) snack(ctx, e.message);
                      } catch (_) {
                        if (ctx.mounted) snack(ctx, 'Gagal menyimpan');
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelola User'), backgroundColor: card),
        body: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tambah user', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: un,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: pw,
                decoration: const InputDecoration(labelText: 'Password (min 6)', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            const Text('Rank', style: TextStyle(color: mu)),
            const SizedBox(height: 6),
            rankChips(rank, (v) => setState(() => rank = v)),
            const SizedBox(height: 14),
            const Text('Masa aktif', style: TextStyle(color: mu)),
            const SizedBox(height: 6),
            DurationPicker(onChanged: (v) => days = v),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : create,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Buat akun'),
              ),
            ),
          ])),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Daftar user', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          box(Column(
            children: users.map((u) {
              final rk = u['rank'] as String;
              final exp = u['expires_at'];
              final can = canManage(u);
              return InkWell(
                onTap: () => edit(u),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    avatar(rk, url: u['avatar_url'] as String?),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RankText(u['username'] as String, rk),
                        Text(
                          '${(ranks[rk] ?? ranks['user']!).name} · ${exp == null ? 'Lifetime' : 's/d ${(exp as String).substring(0, 10)}'}',
                          style: const TextStyle(color: mu, fontSize: 12),
                        ),
                      ]),
                    ),
                    if (can) ...[
                      const Icon(Icons.edit_outlined, size: 18, color: mu),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => del(u),
                        child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFF6B81)),
                      ),
                    ] else
                      const Icon(Icons.lock_outline, size: 18, color: mu),
                  ]),
                ),
              );
            }).toList(),
          )),
        ]),
      );
}


// =====================================================================
// FOTO PROFIL, CROP 1:1, PROFIL USER/GRUP
// =====================================================================
Widget camBadge() => Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ac,
        border: Border.all(color: Colors.white.withOpacity(.8), width: 1.5),
      ),
      child: const Icon(Icons.photo_camera, size: 16, color: Colors.white),
    );

Future<Uint8List?> pickAndCrop(BuildContext c) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 92);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (!c.mounted) return null;
  return Navigator.push<Uint8List>(
      c, MaterialPageRoute<Uint8List>(fullscreenDialog: true, builder: (_) => CropPage(bytes: bytes)));
}

Future<String> uploadAvatar(Uint8List png, String folder) async {
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.png';
  await sb.storage
      .from('avatars')
      .uploadBinary(path, png, fileOptions: const FileOptions(contentType: 'image/png'));
  return sb.storage.from('avatars').getPublicUrl(path);
}

Future<void> changeMyAvatar(BuildContext c) async {
  try {
    final png = await pickAndCrop(c);
    if (png == null) return;
    final url = await uploadAvatar(png, sb.auth.currentUser!.id);
    await sb.rpc('set_my_avatar', params: {'p_url': url});
    if (c.mounted) snack(c, 'Foto profil diperbarui');
  } catch (_) {
    if (c.mounted) snack(c, 'Gagal mengubah foto profil');
  }
}

Future<void> changeGroupAvatar(BuildContext c) async {
  try {
    final png = await pickAndCrop(c);
    if (png == null) return;
    final url = await uploadAvatar(png, 'group');
    await sb.rpc('set_group_avatar', params: {'p_url': url});
    if (c.mounted) snack(c, 'Foto grup diperbarui');
  } catch (_) {
    if (c.mounted) snack(c, 'Gagal mengubah foto grup');
  }
}

class GroupAvatar extends StatefulWidget {
  final double s;
  const GroupAvatar({super.key, this.s = 52});
  @override
  State<GroupAvatar> createState() => _GroupAvatarState();
}

class _GroupAvatarState extends State<GroupAvatar> {
  String? url;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    sub = sb.from('group_settings').stream(primaryKey: ['id']).eq('id', 'main').listen((r) {
      if (mounted) setState(() => url = r.isEmpty ? null : r.first['avatar_url'] as String?);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.groups_outlined, color: Colors.white, size: widget.s * .5);
    return Container(
      width: widget.s,
      height: widget.s,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
      ),
      child: (url == null || url!.isEmpty)
          ? icon
          : Image.network(url!,
              fit: BoxFit.cover,
              width: widget.s,
              height: widget.s,
              errorBuilder: (_, __, ___) => Center(child: icon)),
    );
  }
}

class CropPage extends StatefulWidget {
  final Uint8List bytes;
  const CropPage({super.key, required this.bytes});
  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  final boundaryKey = GlobalKey();
  final tc = TransformationController();
  double iw = 0, ih = 0;
  int turns = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.bytes).then((img) {
      if (!mounted) return;
      setState(() {
        iw = img.width.toDouble();
        ih = img.height.toDouble();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _center());
    });
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  double get _size => MediaQuery.of(context).size.width;
  double get _ew => turns.isOdd ? ih : iw;
  double get _eh => turns.isOdd ? iw : ih;
  double get _scale => _size / (_ew < _eh ? _ew : _eh);

  void _center() {
    if (iw == 0) return;
    final cw = _ew * _scale, ch = _eh * _scale;
    tc.value = Matrix4.identity()..translate(-(cw - _size) / 2, -(ch - _size) / 2);
  }

  void _rotate() {
    setState(() => turns = (turns + 1) % 4);
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  Future<void> _done() async {
    setState(() => busy = true);
    try {
      final b = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 640 / b.size.width);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) Navigator.pop(context, bd!.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        snack(context, 'Gagal memotong foto');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Atur foto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: (busy || iw == 0) ? null : _done,
            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: iw == 0
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(children: [
                      RepaintBoundary(
                        key: boundaryKey,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: tc,
                            constrained: false,
                            minScale: 1,
                            maxScale: 6,
                            boundaryMargin: EdgeInsets.zero,
                            child: SizedBox(
                              width: _ew * _scale,
                              height: _eh * _scale,
                              child: RotatedBox(
                                quarterTurns: turns,
                                child: Image.memory(widget.bytes, fit: BoxFit.fill),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(child: CustomPaint(size: Size(size, size), painter: _CircleMask())),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Geser & cubit untuk mengatur', style: TextStyle(color: mu, fontSize: 13)),
                  IconButton(
                    onPressed: _rotate,
                    icon: const Icon(Icons.rotate_90_degrees_cw_outlined, color: Colors.white),
                  ),
                ]),
              ),
            ]),
    );
  }
}

class _CircleMask extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(rect);
    canvas.drawPath(p, Paint()..color = Colors.black54);
    canvas.drawOval(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserProfilePage extends StatelessWidget {
  final Map<String, dynamic> me, user;
  final String? fromRoom;
  const UserProfilePage({super.key, required this.me, required this.user, this.fromRoom});

  @override
  Widget build(BuildContext context) {
    final myId = sb.auth.currentUser!.id;
    final rank = (user['rank'] ?? 'user') as String;
    final r = ranks[rank] ?? ranks['user']!;
    final name = user['username'] as String;
    final isMe = user['id'] == myId;
    return Stack(children: [
      const Positioned.fill(child: OceanBg()),
      Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(kScrim))),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(children: [
              const SizedBox(height: 16),
              avatar(rank, s: 132, url: user['avatar_url'] as String?),
              const SizedBox(height: 18),
              RankText(name, rank, size: 28),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
                decoration: BoxDecoration(
                  color: bg.withOpacity(.55),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withOpacity(.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(r.icon, size: 16, color: r.solid),
                  const SizedBox(width: 6),
                  RankText(r.name, rank, size: 13),
                ]),
              ),
              const SizedBox(height: 28),
              if (!isMe)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: GlassButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: 'Kirim pesan',
                    onPressed: () {
                      final room = dmRoom(myId, user['id'] as String);
                      if (fromRoom == room) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pushReplacement(context,
                          CupertinoPageRoute(builder: (_) => ChatRoomPage(me: me, peer: user)));
                    },
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class GroupProfilePage extends StatelessWidget {
  final Map<String, dynamic> me;
  const GroupProfilePage({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final isDev = me['rank'] == 'developer';
    return Stack(children: [
      const Positioned.fill(child: OceanBg()),
      Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(kScrim))),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(children: [
              const SizedBox(height: 16),
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(clipBehavior: Clip.none, children: [
                  const Positioned(left: 4, top: 4, child: GroupAvatar(s: 132)),
                  if (isDev)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(onTap: () => changeGroupAvatar(context), child: camBadge()),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Chat Utama', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Grup umum', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 28),
              if (isDev)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: GlassButton(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: 'Ubah foto grup',
                    onPressed: () => changeGroupAvatar(context),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// =====================================================================
// MENU LONG-PRESS PESAN (gaya iOS)
// =====================================================================
const kQuick = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥'];

const kEmojiCats = <String, String>{
  'Wajah':
      '😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 😐 😑 😶 😏 😒 🙄 😬 😌 😔 😪 😴 😷 🤒 🤕 🤢 🤮 🥵 🥶 🥴 😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 💩 🤡 👻 👽 🤖',
  'Gestur':
      '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖖 👋 🤝 🙏 ✍️ 💪 👏 🙌 👐 🤲 🙈 🙉 🙊',
  'Hati & simbol':
      '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💯 💢 💥 💫 💦 💨 🔥 ✨ 🎉 🎊',
  'Hewan & alam':
      '🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🦄 🐝 🦋 🌸 🌹 🌻 🌈 ⭐ 🌙 ☀️ ⚡ ❄️',
  'Makanan':
      '🍎 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥑 🍕 🍔 🍟 🌭 🍿 🍜 🍣 🍩 🍪 🎂 🍫 🍭 ☕ 🍺 🥤',
  'Aktivitas & objek':
      '⚽ 🏀 🏈 🎮 🎯 🎵 🎤 🎧 📱 💻 📷 🎁 🏆 🚗 ✈️ 🚀 💡 💰 📌 🔔',
  'Tanda':
      '✅ ❌ ⭕ ❓ ❗ ‼️ ⚠️ 🚫 💤 🆗 🔴 🟢 🔵 🟡 ➕ ➖ ✔️ ➡️ ⬆️ 🔁',
};

Future<String?> showEmojiSheet(BuildContext c) => showModalBottomSheet<String>(
      context: c,
      backgroundColor: card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .6,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
          for (final e in kEmojiCats.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
              child: Text(e.key, style: const TextStyle(color: mu, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Wrap(spacing: 2, runSpacing: 2, children: [
              for (final em in e.value.split(' '))
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(ctx, em),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(em, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );

Future<void> showMsgMenu({
  required BuildContext context,
  required Rect rect,
  required bool mine,
  required Widget bubble,
  required String? myEmoji,
  required bool starred,
  required bool canPin,
  required bool pinned,
  required void Function(String) onReact,
  required VoidCallback onMore,
  required VoidCallback onReply,
  required VoidCallback onForward,
  required VoidCallback onCopy,
  required VoidCallback onStar,
  required VoidCallback onPin,
  required VoidCallback onDeleteMe,
  VoidCallback? onDeleteAll,
}) =>
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _MsgMenuView(
        rect: rect,
        mine: mine,
        bubble: bubble,
        myEmoji: myEmoji,
        starred: starred,
        canPin: canPin,
        pinned: pinned,
        onReact: onReact,
        onMore: onMore,
        onReply: onReply,
        onForward: onForward,
        onCopy: onCopy,
        onStar: onStar,
        onPin: onPin,
        onDeleteMe: onDeleteMe,
        onDeleteAll: onDeleteAll,
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));

class _Mi {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool red;
  const _Mi(this.label, this.icon, this.onTap, {this.red = false});
}

class _MsgMenuView extends StatefulWidget {
  final Rect rect;
  final bool mine, starred, canPin, pinned;
  final Widget bubble;
  final String? myEmoji;
  final void Function(String) onReact;
  final VoidCallback onMore, onReply, onForward, onCopy, onStar, onPin, onDeleteMe;
  final VoidCallback? onDeleteAll;
  const _MsgMenuView({
    required this.rect,
    required this.mine,
    required this.bubble,
    required this.myEmoji,
    required this.starred,
    required this.canPin,
    required this.pinned,
    required this.onReact,
    required this.onMore,
    required this.onReply,
    required this.onForward,
    required this.onCopy,
    required this.onStar,
    required this.onPin,
    required this.onDeleteMe,
    required this.onDeleteAll,
  });
  @override
  State<_MsgMenuView> createState() => _MsgMenuViewState();
}

class _MsgMenuViewState extends State<_MsgMenuView> {
  bool sub = false;
  static const red = Color(0xFFFF6B81);

  void done(VoidCallback f) {
    Navigator.of(context).pop();
    f();
  }

  List<_Mi> items() {
    final w = widget;
    if (sub) {
      return [
        _Mi('Hapus untuk saya', Icons.visibility_off_outlined, () => done(w.onDeleteMe)),
        _Mi('Hapus untuk semua orang', Icons.delete_outline, () => done(w.onDeleteAll!), red: true),
        _Mi('Kembali', Icons.arrow_back_ios_new_rounded, () => setState(() => sub = false)),
      ];
    }
    return [
      _Mi('Balas', Icons.reply, () => done(w.onReply)),
      _Mi('Teruskan', Icons.forward, () => done(w.onForward)),
      _Mi('Salin', Icons.content_copy, () => done(w.onCopy)),
      _Mi(w.starred ? 'Hapus bintang' : 'Beri bintang', w.starred ? Icons.star : Icons.star_border,
          () => done(w.onStar)),
      if (w.canPin)
        _Mi(w.pinned ? 'Lepas sematan' : 'Sematkan pesan', Icons.push_pin_outlined, () => done(w.onPin)),
      if (w.onDeleteAll != null)
        _Mi('Hapus', Icons.delete_outline, () => setState(() => sub = true), red: true)
      else
        _Mi('Hapus untuk saya', Icons.delete_outline, () => done(w.onDeleteMe), red: true),
    ];
  }

  Widget _pop(Alignment a, Widget child) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: .85, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (_, v, c) => Opacity(
          opacity: v >= 1 ? 1.0 : ((v - .85) / .15).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: v, alignment: a, child: c),
        ),
        child: child,
      );

  Widget emojiBar() => Glass(
        radius: 30,
        blur: 16,
        strength: .62,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final e in kQuick)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => done(() => widget.onReact(e)),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.myEmoji == e ? Colors.white.withOpacity(.22) : Colors.transparent,
                ),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => done(widget.onMore),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.18)),
              child: const Icon(Icons.add, size: 22, color: Colors.white),
            ),
          ),
        ]),
      );

  Widget menu(List<_Mi> its, double rowH) => Glass(
        radius: 18,
        blur: 18,
        strength: .66,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < its.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: .5, color: Colors.white.withOpacity(.14)),
            InkWell(
              onTap: its[i].onTap,
              child: SizedBox(
                height: rowH,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Text(its[i].label,
                          style: TextStyle(fontSize: 16, color: its[i].red ? red : Colors.white)),
                    ),
                    Icon(its[i].icon, size: 21, color: its[i].red ? red : Colors.white),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width, h = mq.size.height;
    final topLim = mq.padding.top + 8, botLim = h - mq.padding.bottom - 12;
    const barH = 56.0, gap = 8.0, rowH = 50.0;
    final its = items();
    final menuH = its.length * rowH;
    final rect = widget.rect;
    final barW = (w - 24) < 364.0 ? (w - 24) : 364.0;
    final menuW = (w - 24) < 260.0 ? (w - 24) : 260.0;
    double leftFor(double width) {
      final l = widget.mine ? rect.right - width : rect.left;
      final hi = w - 12 - width;
      return l < 12 ? 12 : (l > hi ? hi : l);
    }

    final startY = rect.top - gap - barH;
    final endY = rect.bottom + gap + menuH;
    var dy = 0.0;
    if (endY > botLim) dy = botLim - endY;
    if (startY + dy < topLim) dy = topLim - startY;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: ColoredBox(color: Colors.black.withOpacity(.38)),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: dy),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Stack(children: [
              Positioned(
                left: leftFor(barW),
                top: startY + v,
                width: barW,
                height: barH,
                child: _pop(widget.mine ? Alignment.bottomRight : Alignment.bottomLeft, emojiBar()),
              ),
              Positioned(left: rect.left, top: rect.top + v, child: widget.bubble),
              Positioned(
                left: leftFor(menuW),
                top: rect.bottom + gap + v,
                width: menuW,
                child: _pop(widget.mine ? Alignment.topRight : Alignment.topLeft, menu(its, rowH)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
