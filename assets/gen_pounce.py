import os

OL = '#45475a'
BODY = '#7f849c'
DARK = '#6c7086'
LIGHT = '#bac2de'
WHITE = '#cdd6f4'
PINK = '#f5c2e7'
NOSE = '#f38ba8'

pounce = f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(0, 102)">
  <!-- Tail -->
  <path d="M 30,62 C 20,54 10,42 6,30 C 2,18 6,10 12,6 C 18,2 24,6 22,14
           C 20,22 18,32 22,44 C 26,54 30,60 34,64" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 12,6 C 18,2 24,6 22,14 C 20,8 16,4 12,6Z" fill="{WHITE}"/>

  <!-- Back legs extended -->
  <path d="M 38,82 C 30,86 22,94 18,102 C 16,108 20,112 26,110
           C 32,108 34,102 32,96 C 30,90 34,86 38,82" fill="{BODY}"/>
  <ellipse cx="24" cy="108" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="20" cy="109" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="24" cy="110" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="28" cy="109" r="2" fill="{PINK}" opacity="0.8"/>

  <path d="M 46,84 C 40,88 34,96 30,104 C 28,110 32,114 38,112
           C 44,110 46,104 44,98 C 42,92 44,88 48,84" fill="{BODY}"/>
  <ellipse cx="36" cy="110" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="32" cy="111" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="36" cy="112" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="40" cy="111" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Body -->
  <ellipse cx="72" cy="72" rx="42" ry="20" fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="72" cy="76" rx="30" ry="10" fill="{LIGHT}"/>

  <!-- Front legs reaching -->
  <path d="M 100,78 C 108,86 116,96 120,106 C 122,112 118,116 112,114
           C 106,112 106,106 108,100 C 110,94 106,86 102,80" fill="{BODY}"/>
  <ellipse cx="116" cy="112" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <ellipse cx="116" cy="111" rx="4" ry="2.5" fill="{PINK}" opacity="0.9"/>
  <circle cx="112" cy="114" r="2" fill="{PINK}" opacity="0.9"/>
  <circle cx="116" cy="115" r="1.6" fill="{PINK}" opacity="0.9"/>
  <circle cx="120" cy="114" r="2" fill="{PINK}" opacity="0.9"/>

  <path d="M 94,80 C 100,88 106,98 108,108 C 110,114 106,118 100,116
           C 94,114 94,108 96,102 C 98,96 96,88 94,82" fill="{BODY}"/>
  <ellipse cx="104" cy="114" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="100" cy="115" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="104" cy="116" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="108" cy="115" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Neck -->
  <path d="M 102,64 C 108,56 116,50 124,48 C 130,46 132,50 128,58
           C 124,66 118,72 110,74 C 104,76 100,72 102,64Z" fill="{BODY}"/>
  <path d="M 106,60 C 110,54 118,50 124,48 C 122,56 116,64 110,68Z" fill="{WHITE}" opacity="0.6"/>

  <!-- Far ear -->
  <path d="M 134,18 Q 130,4 136,-2 Q 142,6 142,18 Z" fill="{DARK}" stroke="{OL}" stroke-width="1.5"/>
  <!-- Near ear -->
  <path d="M 154,20 Q 166,-2 158,-6 Q 148,4 146,18 Z" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 152,16 Q 160,2 156,-2 Q 150,6 148,16 Z" fill="white"/>

  <!-- Head -->
  <ellipse cx="150" cy="38" rx="36" ry="34" fill="{BODY}" stroke="{OL}" stroke-width="2.5"/>
  <ellipse cx="170" cy="50" rx="14" ry="10" fill="{WHITE}"/>
  <path d="M 150,20 C 148,16 143,16 143,20 C 143,24 150,28 150,28
           C 150,28 157,24 157,20 C 157,16 152,16 150,20Z" fill="{WHITE}"/>

  <!-- Eye -->
  <ellipse cx="162" cy="38" rx="12" ry="14" fill="white" stroke="{OL}" stroke-width="2"/>
  <ellipse cx="163" cy="40" rx="10" ry="12" fill="#89b4fa"/>
  <ellipse cx="163" cy="37" rx="8" ry="5" fill="#5e8ad4" opacity="0.4"/>
  <ellipse cx="164" cy="42" rx="5" ry="7" fill="#1e1e2e"/>
  <circle cx="168" cy="34" r="3.5" fill="white"/>
  <circle cx="160" cy="46" r="2" fill="white" opacity="0.8"/>

  <path d="M 178,48 C 176,48 175,50 176,51 C 177,52 178,52 178,52
           C 178,52 179,52 180,51 C 181,50 180,48 178,48Z" fill="{NOSE}" stroke="#d4637a" stroke-width="0.5"/>
  <path d="M 178,52 L 178,53.5" stroke="{OL}" stroke-width="0.8" stroke-linecap="round"/>
  <path d="M 176,53 C 176.5,54.5 177.5,53.5 178,53.5" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>
  <path d="M 178,53.5 C 178.5,53.5 179.5,54.5 180,53" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>

  <g stroke="{DARK}" stroke-width="0.7" fill="none" opacity="0.5">
    <path d="M 182,50 Q 192,47 200,46"/>
    <path d="M 182,52 Q 194,52 202,52"/>
    <path d="M 182,54 Q 192,57 200,60"/>
  </g>
  </g>
</svg>'''

land = f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(5, 86)">
  <!-- Tail up -->
  <path d="M 36,68 C 26,58 14,44 8,30 C 2,16 6,8 12,4 C 18,0 24,4 22,12
           C 20,20 18,30 22,42 C 26,54 32,64 38,70" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 12,4 C 18,0 24,4 22,12 C 20,6 16,2 12,4Z" fill="{WHITE}"/>

  <!-- Back legs lifted -->
  <path d="M 40,88 C 34,92 28,100 26,108 C 24,114 28,118 34,116
           C 40,114 42,108 40,102 C 38,96 40,92 42,88" fill="{BODY}"/>
  <ellipse cx="32" cy="114" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="28" cy="115" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="32" cy="116" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="36" cy="115" r="2" fill="{PINK}" opacity="0.8"/>

  <path d="M 52,90 C 48,94 42,102 40,110 C 38,116 42,120 48,118
           C 54,116 56,110 54,104 C 52,98 52,94 54,90" fill="{BODY}"/>
  <ellipse cx="46" cy="116" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="42" cy="117" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="46" cy="118" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="50" cy="117" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Body -->
  <ellipse cx="72" cy="80" rx="40" ry="22" fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="72" cy="84" rx="28" ry="12" fill="{LIGHT}"/>

  <!-- Front legs planted -->
  <path d="M 88,90 C 88,100 88,112 88,122 C 88,128 92,132 98,130
           C 104,128 104,122 102,116 C 100,108 96,100 94,92" fill="{BODY}"/>
  <ellipse cx="96" cy="130" rx="9" ry="4.5" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="92" cy="131" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="96" cy="132" r="1.8" fill="{PINK}" opacity="0.8"/>
  <circle cx="100" cy="131" r="2" fill="{PINK}" opacity="0.8"/>

  <path d="M 100,88 C 100,98 100,110 100,120 C 100,126 104,130 110,128
           C 116,126 116,120 114,114 C 112,106 108,98 106,90" fill="{BODY}"/>
  <ellipse cx="108" cy="128" rx="9" ry="4.5" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="104" cy="129" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="108" cy="130" r="1.8" fill="{PINK}" opacity="0.8"/>
  <circle cx="112" cy="129" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Neck -->
  <path d="M 98,72 C 104,64 112,58 120,54 C 126,52 128,56 124,62
           C 120,68 114,74 106,78 C 100,80 96,78 98,72Z" fill="{BODY}"/>
  <path d="M 102,66 C 106,60 114,56 120,54 C 118,60 112,68 106,72Z" fill="{WHITE}" opacity="0.6"/>

  <!-- Far ear -->
  <path d="M 130,22 Q 126,6 132,-2 Q 138,8 138,20 Z" fill="{DARK}" stroke="{OL}" stroke-width="1.5"/>
  <!-- Near ear -->
  <path d="M 150,24 Q 162,0 154,-4 Q 144,6 142,22 Z" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 148,20 Q 156,4 152,0 Q 146,8 144,18 Z" fill="white"/>

  <!-- Head -->
  <ellipse cx="146" cy="42" rx="36" ry="34" fill="{BODY}" stroke="{OL}" stroke-width="2.5"/>
  <ellipse cx="166" cy="54" rx="14" ry="10" fill="{WHITE}"/>
  <path d="M 146,24 C 144,20 139,20 139,24 C 139,28 146,32 146,32
           C 146,32 153,28 153,24 C 153,20 148,20 146,24Z" fill="{WHITE}"/>

  <ellipse cx="158" cy="42" rx="12" ry="14" fill="white" stroke="{OL}" stroke-width="2"/>
  <ellipse cx="159" cy="44" rx="10" ry="12" fill="#89b4fa"/>
  <ellipse cx="159" cy="41" rx="8" ry="5" fill="#5e8ad4" opacity="0.4"/>
  <ellipse cx="160" cy="46" rx="5" ry="7" fill="#1e1e2e"/>
  <circle cx="164" cy="38" r="3.5" fill="white"/>
  <circle cx="156" cy="50" r="2" fill="white" opacity="0.8"/>

  <path d="M 174,52 C 172,52 171,54 172,55 C 173,56 174,56 174,56
           C 174,56 175,56 176,55 C 177,54 176,52 174,52Z" fill="{NOSE}" stroke="#d4637a" stroke-width="0.5"/>
  <path d="M 174,56 L 174,57.5" stroke="{OL}" stroke-width="0.8" stroke-linecap="round"/>
  <path d="M 172,57 C 172.5,58.5 173.5,57.5 174,57.5" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>
  <path d="M 174,57.5 C 174.5,57.5 175.5,58.5 176,57" stroke="{OL}" stroke-width="0.8" fill="none" stroke-linecap="round"/>

  <g stroke="{DARK}" stroke-width="0.7" fill="none" opacity="0.5">
    <path d="M 178,54 Q 188,51 196,50"/>
    <path d="M 178,56 Q 190,56 198,56"/>
    <path d="M 178,58 Q 188,61 196,64"/>
  </g>
  </g>
</svg>'''

with open(r'C:\Software\copilot-cat\assets\cat_pounce.svg', 'w', encoding='ascii') as f:
    f.write(pounce)
print(f'pounce: {os.path.getsize(r"C:/Software/copilot-cat/assets/cat_pounce.svg")} bytes')

with open(r'C:\Software\copilot-cat\assets\cat_land.svg', 'w', encoding='ascii') as f:
    f.write(land)
print(f'land: {os.path.getsize(r"C:/Software/copilot-cat/assets/cat_land.svg")} bytes')
