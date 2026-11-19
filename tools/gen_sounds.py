import wave, struct, random
SR = 11025
def save(path, s):
    w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 30000)) for x in s)); w.close()
def tone(f0, f1, d, vol=.5, kind='sq', duty=.5):
    n = int(SR * d); out = []; ph = 0
    for i in range(n):
        t = i / n; ph += (f0 + (f1 - f0) * t) / SR; p = ph % 1
        v = (1 if p < duty else -1) if kind == 'sq' else 4 * abs(p - .5) - 1
        out.append(v * vol * (1 - t))
    return out
def noise(d, vol=.5, decay=1.5):
    n = int(SR * d)
    return [random.uniform(-1, 1) * vol * (1 - i / n) ** decay for i in range(n)]
def mix(a, b):
    n = max(len(a), len(b)); a = a + [0] * (n - len(a)); b = b + [0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]
hz = lambda m: 440 * 2 ** ((m - 69) / 12)
random.seed(1)
S = 'assets/sfx/'
save(S + 'jump.wav', tone(300, 750, .18, .4))
save(S + 'coin.wav', tone(988, 988, .07, .4) + tone(1319, 1319, .22, .4))
save(S + 'stomp.wav', mix(tone(220, 60, .16, .7, 'tri'), noise(.06, .4)))
save(S + 'hurt.wav', tone(520, 90, .45, .5, 'sq', .25))
save(S + 'shoot.wav', mix(tone(900, 200, .25, .3), noise(.2, .25)))
save(S + 'bossHit.wav', mix(tone(160, 40, .3, .8, 'tri'), noise(.25, .6)))
save(S + 'boom.wav', noise(1.0, .9, 1.6))
save(S + 'heart.wav', tone(523, 523, .08, .4) + tone(659, 659, .08, .4) + tone(784, 784, .25, .4))
save(S + 'clear.wav', sum([tone(hz(m), hz(m), .13, .4) for m in (60, 64, 67, 72)], []) + tone(hz(76), hz(76), .4, .4))
save(S + 'win.wav', sum([tone(hz(m), hz(m), .16, .4) for m in (60, 64, 67, 72, 67, 72, 76, 79)], []) + tone(hz(84), hz(84), .8, .4))
save(S + 'over.wav', sum([tone(hz(m), hz(m), .3, .4, 'tri') for m in (67, 64, 60, 55)], []))
# music: (scale, base midi, seconds per eighth, seed)
worlds = [([0, 2, 4, 7, 9], 72, .18, 11), ([0, 2, 3, 5, 7, 8, 11], 62, .26, 22),
          ([0, 2, 4, 5, 7, 9, 11], 76, .15, 33), ([0, 1, 4, 5, 7, 8, 11], 60, .17, 44)]
for wi, (sc, base, ed, seed) in enumerate(worlds):
    r = random.Random(seed); deg = 0; mel = []
    for i in range(32):
        deg = max(-3, min(len(sc) + 3, deg + r.choice([-2, -1, -1, 0, 1, 1, 2])))
        mel.append(None if r.random() < .12 else base + sc[deg % len(sc)] + 12 * (deg // len(sc)))
    roots = [0, -4, -7, -2, 0, -4, -7, -9]
    out = []
    for rep in range(2):
        for i, m in enumerate(mel):
            n = int(SR * ed)
            bm = base - 24 + roots[i // 4] + (7 if i % 2 else 0)
            a = tone(hz(m), hz(m), ed, .22, 'sq', .25) if m else [0] * n
            b = tone(hz(bm), hz(bm), ed, .3, 'tri')
            out += mix(a, b)
    save('assets/music/w%d.wav' % wi, out)
