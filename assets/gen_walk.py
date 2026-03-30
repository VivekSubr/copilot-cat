import os

OL = '#45475a'
BODY = '#7f849c'
DARK = '#6c7086'
LIGHT = '#bac2de'
WHITE = '#cdd6f4'
PINK = '#f5c2e7'
NOSE = '#f38ba8'

def walk_svg(frame, eye='blue', cycles=None):
    """eye: 'blue' for walking right, 'amber' for walking left"""
    iris = '#89b4fa' if eye == 'blue' else '#fab387'
    iris_dark = '#5e8ad4' if eye == 'blue' else '#e8956a'
    # Moderate stride - legs stay connected to body
    if cycles is None:
        cycles = {
            0: {'fl': (10, -6),  'fr': (-8, 0),   'bl': (-8, 0),   'br': (10, -6)},
            1: {'fl': (2, -2),   'fr': (2, -2),   'bl': (2, -2),   'br': (2, -2)},
            2: {'fl': (-8, 0),   'fr': (10, -6),  'bl': (10, -6),  'br': (-8, 0)},
            3: {'fl': (2, -2),   'fr': (2, -2),   'bl': (2, -2),   'br': (2, -2)},
        }
    c = cycles[frame]

    def leg(bx, by, dx, dy):
        x = bx + dx
        y = by + dy
        ext = 30 if dy == 0 else 24
        return f'''<path d="M {x+2},{y} C {x},{y+8} {x-2},{y+ext-10} {x},{y+ext}
           C {x+2},{y+ext+4} {x+8},{y+ext+6} {x+12},{y+ext+4}
           C {x+14},{y+ext+2} {x+14},{y+ext-4} {x+12},{y+ext-8}
           C {x+10},{y+ext-14} {x+8},{y+6} {x+6},{y}" fill="{BODY}"/>
    <path d="M {x+2},{y+ext-6} C {x},{y+ext} {x+2},{y+ext+4} {x+6},{y+ext+6}
           C {x+10},{y+ext+7} {x+14},{y+ext+4} {x+14},{y+ext-2}" fill="none" stroke="{OL}" stroke-width="1.6"/>
    <ellipse cx="{x+7}" cy="{y+ext+4}" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
    <circle cx="{x+3}" cy="{y+ext+5}" r="2" fill="{PINK}" opacity="0.8"/>
    <circle cx="{x+7}" cy="{y+ext+6}" r="1.6" fill="{PINK}" opacity="0.8"/>
    <circle cx="{x+11}" cy="{y+ext+5}" r="2" fill="{PINK}" opacity="0.8"/>'''

    svg = f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(5, 87)">
  <!-- Tail - fills into body area so body hides seam -->
  <path d="M 42,72 C 32,62 18,46 12,32 C 6,18 10,8 16,4 C 22,0 28,4 26,12
           C 24,20 22,32 26,46 C 30,58 38,68 44,74" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 16,4 C 22,0 28,4 26,12 C 24,6 20,2 16,4Z" fill="{WHITE}"/>

  <!-- Back legs -->
  {leg(44, 94, c['bl'][0], c['bl'][1])}
  {leg(58, 94, c['br'][0], c['br'][1])}

  <!-- Body oval -->
  <ellipse cx="72" cy="84" rx="40" ry="22" fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="72" cy="88" rx="28" ry="12" fill="{LIGHT}"/>

  <!-- Front legs -->
  {leg(76, 92, c['fl'][0], c['fl'][1])}
  {leg(92, 92, c['fr'][0], c['fr'][1])}

  <!-- Neck fill - same color as body, covers the gap -->
  <path d="M 98,76 C 104,68 112,60 120,56 C 128,52 132,56 128,64
           C 124,72 116,78 108,82 C 102,86 98,84 98,76Z" fill="{BODY}"/>

  <!-- Far ear (behind head, slightly visible) -->
  <path d="M 132,26 Q 128,10 134,4 Q 140,12 140,24 Z" fill="{DARK}" stroke="{OL}" stroke-width="1.5"/>

  <!-- Near ear (big, like idle) -->
  <path d="M 152,28 Q 164,4 156,-2 Q 146,10 144,26 Z" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 150,24 Q 158,8 154,2 Q 148,12 146,22 Z" fill="white"/>

  <!-- Head - big chibi circle, overlaps neck -->
  <ellipse cx="148" cy="46" rx="36" ry="34" fill="{BODY}" stroke="{OL}" stroke-width="2.5"/>

  <!-- Muzzle -->
  <ellipse cx="168" cy="58" rx="14" ry="10" fill="{WHITE}"/>

  <!-- Heart -->
  <path d="M 148,28 C 146,24 141,24 141,28 C 141,32 148,36 148,36
           C 148,36 155,32 155,28 C 155,24 150,24 148,28Z" fill="{WHITE}"/>

  <!-- Eye -->
  <ellipse cx="160" cy="46" rx="12" ry="14" fill="white" stroke="{OL}" stroke-width="2"/>
  <ellipse cx="161" cy="48" rx="10" ry="12" fill="{iris}"/>
  <ellipse cx="161" cy="45" rx="8" ry="5" fill="{iris_dark}" opacity="0.4"/>
  <ellipse cx="162" cy="50" rx="5" ry="7" fill="#1e1e2e"/>
  <circle cx="166" cy="42" r="3.5" fill="white"/>
  <circle cx="158" cy="54" r="2" fill="white" opacity="0.8"/>
  <circle cx="166" cy="51" r="1.2" fill="white" opacity="0.5"/>

  <!-- Nose -->
  <path d="M 176,56 C 174,56 173,58 174,59 C 175,60 176,60 176,60
           C 176,60 177,60 178,59 C 179,58 178,56 176,56Z" fill="{NOSE}" stroke="#d4637a" stroke-width="0.5"/>

  <!-- Mouth -->
  <path d="M 176,60 L 176,61.5" stroke="{OL}" stroke-width="0.8" stroke-linecap="round"/>
  <path d="M 174,61 C 174.5,62.5 175.5,61.5 176,61.5" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>
  <path d="M 176,61.5 C 176.5,61.5 177.5,62.5 178,61" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>

  <!-- Whiskers -->
  <g stroke="{DARK}" stroke-width="0.7" fill="none" opacity="0.5">
    <path d="M 180,58 Q 190,55 198,54"/>
    <path d="M 180,60 Q 192,60 200,60"/>
    <path d="M 180,62 Q 190,65 198,68"/>
  </g>
  </g>
</svg>'''
    return svg


for i in range(4):
    # Blue eye (facing right)
    name = f'cat_walk{i+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w', encoding='ascii') as f:
        f.write(walk_svg(i, 'blue'))
    print(f'{name}: {os.path.getsize(path)} bytes')

    # Amber eye (facing left)
    name_l = f'cat_walk{i+1}_left'
    path_l = rf'C:\Software\copilot-cat\assets\{name_l}.svg'
    with open(path_l, 'w', encoding='ascii') as f:
        f.write(walk_svg(i, 'amber'))
    print(f'{name_l}: {os.path.getsize(path_l)} bytes')

# --- Variant B: 8-frame walk cycle (interpolated from 4 keyframes) ---

base = {
    0: {'fl': (10, -6),  'fr': (-8, 0),   'bl': (-8, 0),   'br': (10, -6)},
    1: {'fl': (2, -2),   'fr': (2, -2),   'bl': (2, -2),   'br': (2, -2)},
    2: {'fl': (-8, 0),   'fr': (10, -6),  'bl': (10, -6),  'br': (-8, 0)},
    3: {'fl': (2, -2),   'fr': (2, -2),   'bl': (2, -2),   'br': (2, -2)},
}

def midpoint(a, b):
    """Halfway interpolation between two leg-offset dicts."""
    return {k: ((a[k][0] + b[k][0]) // 2, (a[k][1] + b[k][1]) // 2) for k in a}

cycles_b = {
    0: base[0],
    1: midpoint(base[0], base[1]),
    2: base[1],
    3: midpoint(base[1], base[2]),
    4: base[2],
    5: midpoint(base[2], base[3]),
    6: base[3],
    7: midpoint(base[3], base[0]),
}

for i in range(8):
    name = f'cat_walk_b{i+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w', encoding='ascii') as f:
        f.write(walk_svg(i, 'blue', cycles_b))
    print(f'{name}: {os.path.getsize(path)} bytes')

    name_l = f'cat_walk_b{i+1}_left'
    path_l = rf'C:\Software\copilot-cat\assets\{name_l}.svg'
    with open(path_l, 'w', encoding='ascii') as f:
        f.write(walk_svg(i, 'amber', cycles_b))
    print(f'{name_l}: {os.path.getsize(path_l)} bytes')
