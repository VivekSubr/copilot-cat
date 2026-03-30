import math, os, re

# Color palette
C = {
    'body': '#7f849c', 'dark': '#6c7086', 'darker': '#45475a',
    'light': '#bac2de', 'white': '#cdd6f4', 'pink': '#f5c2e7',
    'nose': '#f38ba8', 'noseDark': '#d4637a',
    'eyeAmber': '#fab387', 'eyeAmberDark': '#e8956a',
    'eyeBlue': '#89b4fa', 'eyeBlueDark': '#5e8ad4',
    'pupil': '#1e1e2e', 'outline': '#45475a'
}

OL = C['outline']

def eye(cx, cy, rx, ry, iris, irisDark, squint=False):
    ey = ry * (0.65 if squint else 1.0)
    ir = rx - 3
    ier = min(ey - 2, ry - 3)
    pr = rx * 0.4
    per = min(ey * 0.45, ey - 4)
    return f'''<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ey:.0f}" fill="white" stroke="{OL}" stroke-width="2.5"/>
  <ellipse cx="{cx}" cy="{cy+2}" rx="{ir}" ry="{ier:.0f}" fill="{iris}"/>
  <ellipse cx="{cx}" cy="{cy-2}" rx="{ir-1}" ry="{min(6, ey*0.35):.0f}" fill="{irisDark}" opacity="0.4"/>
  <ellipse cx="{cx}" cy="{cy+3}" rx="{pr:.0f}" ry="{per:.0f}" fill="{C['pupil']}"/>
  <circle cx="{cx+rx*0.4:.0f}" cy="{cy-ey*0.35:.0f}" r="{rx*0.28:.1f}" fill="white"/>
  <circle cx="{cx-rx*0.3:.0f}" cy="{cy+ey*0.3:.0f}" r="{rx*0.17:.1f}" fill="white" opacity="0.8"/>'''

def nose_mouth(cx, ny):
    return f'''<path d="M {cx},{ny} C {cx-3},{ny} {cx-5},{ny+2} {cx-3},{ny+4} C {cx-2},{ny+5} {cx},{ny+6} {cx},{ny+6} C {cx},{ny+6} {cx+2},{ny+5} {cx+3},{ny+4} C {cx+5},{ny+2} {cx+3},{ny} {cx},{ny}Z" fill="{C['nose']}" stroke="{C['noseDark']}" stroke-width="0.7"/>
  <path d="M {cx},{ny+6} L {cx},{ny+8}" stroke="{OL}" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M {cx-4},{ny+7.5} C {cx-2},{ny+10} {cx-1},{ny+8} {cx},{ny+8}" stroke="{OL}" stroke-width="1.2" fill="none" stroke-linecap="round"/>
  <path d="M {cx},{ny+8} C {cx+1},{ny+8} {cx+2},{ny+10} {cx+4},{ny+7.5}" stroke="{OL}" stroke-width="1.2" fill="none" stroke-linecap="round"/>'''

def whiskers(cx, wy):
    return f'''<g stroke="{C['dark']}" stroke-width="1" fill="none" opacity="0.6">
    <path d="M {cx-22},{wy-3} Q {cx-48},{wy-8} {cx-75},{wy-10}"/>
    <path d="M {cx-24},{wy+1} Q {cx-52},{wy+1} {cx-80},{wy+1}"/>
    <path d="M {cx-22},{wy+5} Q {cx-48},{wy+10} {cx-72},{wy+15}"/>
    <path d="M {cx+22},{wy-3} Q {cx+48},{wy-8} {cx+75},{wy-10}"/>
    <path d="M {cx+24},{wy+1} Q {cx+52},{wy+1} {cx+80},{wy+1}"/>
    <path d="M {cx+22},{wy+5} Q {cx+48},{wy+10} {cx+72},{wy+15}"/>
  </g>'''

def heart(cx, cy, s=11):
    return f'<path d="M {cx},{cy+s*0.55} C {cx-s*0.3},{cy-s*0.15} {cx-s},{cy-s*0.15} {cx-s},{cy+s*0.15} C {cx-s},{cy+s*0.55} {cx},{cy+s} {cx},{cy+s} C {cx},{cy+s} {cx+s},{cy+s*0.55} {cx+s},{cy+s*0.15} C {cx+s},{cy-s*0.15} {cx+s*0.3},{cy-s*0.15} {cx},{cy+s*0.55}Z" fill="{C["white"]}"/>'

def paw(cx, cy):
    return f'''<ellipse cx="{cx}" cy="{cy}" rx="11" ry="5.5" fill="{C['dark']}" stroke="{OL}" stroke-width="1.5"/>
  <circle cx="{cx-5}" cy="{cy+1}" r="2.5" fill="{C['pink']}" opacity="0.8"/>
  <circle cx="{cx}" cy="{cy+2}" r="2" fill="{C['pink']}" opacity="0.8"/>
  <circle cx="{cx+5}" cy="{cy+1}" r="2.5" fill="{C['pink']}" opacity="0.8"/>'''

def make_idle():
    cx = 105
    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  <path d="M 68,170 C 55,155 35,130 28,105 C 20,80 28,55 25,35 C 22,20 15,16 19,8 C 25,0 35,8 33,22 C 31,36 37,60 40,85 C 43,110 55,145 65,165" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 19,8 C 25,0 35,8 33,22 C 29,14 23,6 19,8Z" fill="{C['white']}"/>

  <!-- Back legs -->
  <path d="M 65,176 C 57,184 52,196 54,206 C 56,212 62,214 68,212" fill="{C['body']}"/>
  <path d="M 56,200 C 54,206 56,212 62,214 C 66,215 70,212 70,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(62, 212)}
  <path d="M 145,176 C 148,184 152,196 150,206 C 148,212 142,214 136,212" fill="{C['body']}"/>
  <path d="M 148,200 C 150,206 148,212 142,214 C 138,215 134,212 134,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(142, 212)}

  <!-- Body+Head+Ears silhouette -->
  <path d="M 65,198 C 78,202 132,202 145,198 C 153,192 155,182 155,170 C 155,160 156,148 158,132 C 162,115 164,100 156,80 Q 176,38 162,18 Q 146,34 130,58 C 120,50 90,50 80,58 Q 64,34 48,18 Q 34,38 54,80 C 46,100 48,115 52,132 C 56,148 55,160 55,170 C 55,182 57,192 65,198 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <!-- Ear inners -->
  <path d="M 58,76 Q 44,44 52,26 Q 62,40 74,62 Z" fill="white"/>
  <path d="M 152,76 Q 166,44 158,26 Q 148,40 136,62 Z" fill="white"/>

  <!-- Belly -->
  <ellipse cx="{cx}" cy="176" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front legs -->
  <path d="M 80,180 C 76,190 74,200 76,208 C 78,214 84,217 90,215" fill="{C['body']}"/>
  <path d="M 78,202 C 76,208 78,214 82,216 C 86,217 90,215 92,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(84, 215)}
  <path d="M 130,180 C 128,190 126,200 124,208 C 122,214 126,217 132,215" fill="{C['body']}"/>
  <path d="M 126,202 C 124,208 125,214 130,216 C 135,217 140,215 140,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(132, 215)}

  <!-- Muzzle -->
  <ellipse cx="{cx}" cy="120" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 77)}
  {eye(cx-23, 97, 17, 19, C['eyeAmber'], C['eyeAmberDark'])}
  {eye(cx+23, 97, 17, 19, C['eyeBlue'], C['eyeBlueDark'])}
  {nose_mouth(cx, 122)}
  {whiskers(cx, 126)}
</svg>'''

def make_sit():
    cx = 96
    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(5, 1)">
  <!-- Tail wrapping right -->
  <path d="M 148,178 C 158,174 168,162 172,148 C 176,134 172,122 164,118 C 156,114 148,120 150,128 C 152,136 150,148 144,158 C 138,168 132,174 128,176" fill="{C['body']}" stroke="{OL}" stroke-width="2"/>
  <path d="M 164,118 C 156,114 148,120 150,128 C 150,122 154,116 164,118Z" fill="{C['white']}"/>

  <!-- Back legs tucked -->
  <path d="M 55,192 C 48,194 42,198 42,204 C 42,210 48,212 54,212" fill="{C['body']}"/>
  {paw(52, 210)}
  <path d="M 135,192 C 138,194 142,198 142,204 C 142,210 136,212 130,212" fill="{C['body']}"/>
  {paw(132, 210)}

  <!-- Body+Head+Ears -->
  <path d="M 58,200 C 72,206 118,206 132,200 C 142,194 148,182 148,168 C 148,156 150,142 154,128 C 158,112 158,96 150,78 Q 170,38 156,18 Q 140,34 124,56 C 114,48 78,48 68,56 Q 52,34 36,18 Q 22,38 42,78 C 34,96 34,112 38,128 C 42,142 44,156 44,168 C 44,182 50,194 58,200 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <path d="M 46,76 Q 32,44 40,26 Q 50,40 62,62 Z" fill="white"/>
  <path d="M 146,76 Q 160,44 152,26 Q 142,40 130,62 Z" fill="white"/>

  <ellipse cx="{cx}" cy="182" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front paws neatly together -->
  <path d="M 72,190 C 68,196 66,202 68,208 C 70,214 76,216 82,214" fill="{C['body']}"/>
  <path d="M 70,204 C 68,208 70,214 76,216 C 80,217 84,214 85,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(78, 214)}
  <path d="M 114,190 C 112,196 108,202 106,208 C 104,214 108,216 114,214" fill="{C['body']}"/>
  <path d="M 106,204 C 104,210 108,216 114,216 C 120,216 122,212 122,208" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(112, 214)}

  <ellipse cx="{cx}" cy="120" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 77)}
  {eye(cx-23, 97, 17, 19, C['eyeAmber'], C['eyeAmberDark'], squint=True)}
  {eye(cx+23, 97, 17, 19, C['eyeBlue'], C['eyeBlueDark'], squint=True)}
  {nose_mouth(cx, 122)}
  {whiskers(cx, 126)}
  </g>
</svg>'''

def make_walk(frame):
    '''3/4 view walk, frame 0 or 1'''
    # Frame 0: left front forward. Frame 1: right front forward.
    hx, hy = 178, 56  # head center
    return f'''<svg viewBox="0 0 250 190" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  <path d="M 62,112 C 50,102 32,82 22,62 C 14,42 18,26 22,16 C 26,8 34,8 34,16 C 34,24 28,38 28,54 C 28,70 40,95 55,108" fill="{C['body']}" stroke="{OL}" stroke-width="2"/>
  <path d="M 22,16 C 26,8 34,8 34,16 C 30,12 26,10 22,16Z" fill="{C['white']}"/>

  <!-- Back legs -->
  {"" if frame == 0 else ""}
  <path d="M {58 if frame==0 else 72},138 C {48 if frame==0 else 72},{148 if frame==0 else 148} {36 if frame==0 else 74},{162 if frame==0 else 162} {34 if frame==0 else 76},{172 if frame==0 else 170} C {32 if frame==0 else 78},{178 if frame==0 else 176} {36 if frame==0 else 74},{182 if frame==0 else 180} {42 if frame==0 else 68},{182 if frame==0 else 180}" fill="{C['body']}"/>
  <path d="M {38 if frame==0 else 74},{168 if frame==0 else 166} C {34 if frame==0 else 76},{174 if frame==0 else 172} {36 if frame==0 else 74},{180 if frame==0 else 178} {42 if frame==0 else 68},{182 if frame==0 else 180} C {46 if frame==0 else 64},{183 if frame==0 else 181} {50 if frame==0 else 60},{180 if frame==0 else 178} {49 if frame==0 else 62},{176 if frame==0 else 174}" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(42 if frame==0 else 68, 180 if frame==0 else 178)}

  <path d="M {72 if frame==0 else 58},136 C {72 if frame==0 else 52},{146 if frame==0 else 146} {74 if frame==0 else 48},{160 if frame==0 else 158} {76 if frame==0 else 50},{170 if frame==0 else 168} C {78 if frame==0 else 52},{176 if frame==0 else 174} {74 if frame==0 else 54},{180 if frame==0 else 178} {68 if frame==0 else 60},{180 if frame==0 else 178}" fill="{C['body']}"/>
  {paw(68 if frame==0 else 60, 178 if frame==0 else 176)}

  <!-- Body -->
  <path d="M 44,118 C 44,100 60,90 90,88 C 120,86 148,90 158,100 C 168,110 168,128 158,136 C 148,144 118,148 88,148 C 58,148 44,138 44,118 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="100" cy="132" rx="42" ry="11" fill="{C['light']}"/>

  <!-- Front legs -->
  <path d="M {148 if frame==0 else 138},128 C {155 if frame==0 else 144},{138 if frame==0 else 136} {168 if frame==0 else 156},{152 if frame==0 else 148} {176 if frame==0 else 164},{162 if frame==0 else 158} C {182 if frame==0 else 170},{168 if frame==0 else 164} {178 if frame==0 else 166},{174 if frame==0 else 170} {172 if frame==0 else 160},{174 if frame==0 else 170}" fill="{C['body']}"/>
  <path d="M {174 if frame==0 else 162},{160 if frame==0 else 156} C {180 if frame==0 else 168},{166 if frame==0 else 162} {180 if frame==0 else 168},{172 if frame==0 else 168} {174 if frame==0 else 162},{174 if frame==0 else 170} C {168 if frame==0 else 156},{176 if frame==0 else 172} {164 if frame==0 else 152},{174 if frame==0 else 170} {164 if frame==0 else 154},{170 if frame==0 else 166}" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(172 if frame==0 else 160, 172 if frame==0 else 168)}

  <path d="M {138 if frame==0 else 148},130 C {136 if frame==0 else 148},{142 if frame==0 else 142} {134 if frame==0 else 148},{158 if frame==0 else 158} {134 if frame==0 else 150},{168 if frame==0 else 168} C {134 if frame==0 else 152},{174 if frame==0 else 174} {138 if frame==0 else 148},{178 if frame==0 else 178} {144 if frame==0 else 142},{178 if frame==0 else 178}" fill="{C['body']}"/>
  {paw(142 if frame==0 else 144, 176 if frame==0 else 176)}

  <!-- Chest fluff -->
  <path d="M 150,96 C 158,88 164,86 170,86 C 168,94 162,104 154,108 Z" fill="{C['white']}"/>

  <!-- Ears behind head -->
  <path d="M 150,38 Q 130,4 144,-6 Q 160,8 168,32 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2"/>
  <path d="M 154,34 Q 138,8 148,-2 Q 160,12 164,30 Z" fill="{C['dark']}"/>
  <path d="M 200,32 Q 224,-4 214,-10 Q 198,4 190,28 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 198,28 Q 216,-2 210,-6 Q 200,6 194,26 Z" fill="white"/>

  <!-- Head -->
  <path d="M 138,{hy} C 138,30 156,16 {hx},16 C 200,16 218,30 218,{hy} C 218,82 200,98 {hx},98 C 156,98 138,82 138,{hy} Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5"/>

  <ellipse cx="196" cy="72" rx="20" ry="14" fill="{C['white']}"/>
  {heart(hx, 38)}

  <!-- Far eye (amber, slightly smaller) -->
  {eye(162, 60, 13, 16, C['eyeAmber'], C['eyeAmberDark'])}
  <!-- Near eye (blue, full size) -->
  {eye(200, 58, 16, 19, C['eyeBlue'], C['eyeBlueDark'])}

  {nose_mouth(206, 70)}

  <g stroke="{C['dark']}" stroke-width="0.9" fill="none" opacity="0.5">
    <path d="M 218,72 Q 234,68 248,66"/>
    <path d="M 220,75 Q 236,75 250,75"/>
    <path d="M 218,78 Q 234,82 246,86"/>
  </g>
</svg>'''

def make_stretch():
    '''Cat stretching - side profile matching walk style.
    Front legs extended far forward, chest very low, rear raised, tail up, yawning.'''
    BODY = C['body']
    DARK = C['dark']
    LIGHT = C['light']
    WHITE = C['white']
    PINK = C['pink']
    NOSE = C['nose']
    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(5, 87)">
  <!-- Tail raised high and curled -->
  <path d="M 36,68 C 24,52 14,30 10,14 C 6,-2 12,-12 18,-16 C 24,-20 30,-16 28,-8
           C 26,0 24,16 28,34 C 32,52 38,64 40,70" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 18,-16 C 24,-20 30,-16 28,-8 C 26,-14 22,-18 18,-16Z" fill="{WHITE}"/>

  <!-- Back legs (standing tall - butt is raised) -->
  <path d="M 40,86 C 36,96 34,108 36,118 C 38,124 42,126 46,124" fill="{BODY}"/>
  <path d="M 36,114 C 34,120 36,124 40,126 C 44,127 48,124 48,120" fill="none" stroke="{OL}" stroke-width="1.6"/>
  <ellipse cx="42" cy="124" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="38" cy="125" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="42" cy="126" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="46" cy="125" r="2" fill="{PINK}" opacity="0.8"/>
  <path d="M 56,86 C 52,96 50,108 52,118 C 54,124 58,126 62,124" fill="{BODY}"/>
  <path d="M 52,114 C 50,120 52,124 56,126 C 60,127 64,124 64,120" fill="none" stroke="{OL}" stroke-width="1.6"/>
  <ellipse cx="58" cy="124" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="54" cy="125" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="58" cy="126" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="62" cy="125" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Body - rear raised, chest very low (diagonal slope) -->
  <path d="M 44,76 C 56,72 76,78 92,90 C 108,102 118,110 122,114"
        fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="62" cy="80" rx="26" ry="18" fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="62" cy="84" rx="18" ry="10" fill="{LIGHT}"/>
  <!-- Lower body toward head -->
  <ellipse cx="108" cy="108" rx="24" ry="16" fill="{BODY}" stroke="{OL}" stroke-width="2.2"/>
  <ellipse cx="108" cy="112" rx="16" ry="8" fill="{LIGHT}"/>

  <!-- Front legs extended far forward, flat on ground -->
  <path d="M 112,112 C 120,118 132,124 142,126 C 148,128 152,126 152,122" fill="{BODY}"/>
  <path d="M 138,124 C 144,126 150,126 152,122 C 152,120 150,118 146,118" fill="none" stroke="{OL}" stroke-width="1.6"/>
  <ellipse cx="148" cy="124" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="144" cy="125" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="148" cy="126" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="152" cy="125" r="2" fill="{PINK}" opacity="0.8"/>
  <path d="M 118,114 C 126,120 138,126 148,128 C 154,130 158,128 158,124" fill="{BODY}"/>
  <path d="M 144,126 C 150,128 156,128 158,124 C 158,122 156,120 152,120" fill="none" stroke="{OL}" stroke-width="1.6"/>
  <ellipse cx="154" cy="126" rx="8" ry="4" fill="{DARK}" stroke="{OL}" stroke-width="1.4"/>
  <circle cx="150" cy="127" r="2" fill="{PINK}" opacity="0.8"/>
  <circle cx="154" cy="128" r="1.6" fill="{PINK}" opacity="0.8"/>
  <circle cx="158" cy="127" r="2" fill="{PINK}" opacity="0.8"/>

  <!-- Neck fill -->
  <path d="M 120,104 C 128,98 136,92 142,90 C 148,88 150,92 146,98
           C 142,104 136,108 130,110 C 126,112 122,110 120,104Z" fill="{BODY}"/>

  <!-- Far ear -->
  <path d="M 148,68 Q 144,52 150,46 Q 156,54 156,66 Z" fill="{DARK}" stroke="{OL}" stroke-width="1.5"/>

  <!-- Near ear -->
  <path d="M 168,70 Q 180,46 172,40 Q 162,52 160,68 Z" fill="{BODY}" stroke="{OL}" stroke-width="2"/>
  <path d="M 166,66 Q 174,50 170,44 Q 164,54 162,64 Z" fill="white"/>

  <!-- Head (low, near ground level) -->
  <ellipse cx="162" cy="88" rx="30" ry="28" fill="{BODY}" stroke="{OL}" stroke-width="2.5"/>

  <!-- Muzzle -->
  <ellipse cx="180" cy="98" rx="12" ry="9" fill="{WHITE}"/>

  <!-- Heart -->
  <path d="M 162,72 C 160,68 155,68 155,72 C 155,76 162,80 162,80
           C 162,80 169,76 169,72 C 169,68 164,68 162,72Z" fill="{WHITE}"/>

  <!-- Squinty happy eye -->
  <ellipse cx="174" cy="86" rx="10" ry="7" fill="white" stroke="{OL}" stroke-width="2"/>
  <ellipse cx="175" cy="88" rx="8" ry="5" fill="{C['eyeAmber']}"/>
  <ellipse cx="175" cy="86" rx="7" ry="3" fill="{C['eyeAmberDark']}" opacity="0.4"/>
  <ellipse cx="176" cy="89" rx="4" ry="3" fill="#1e1e2e"/>
  <circle cx="178" cy="84" r="2.5" fill="white"/>
  <circle cx="172" cy="91" r="1.5" fill="white" opacity="0.8"/>

  <!-- Open yawn mouth -->
  <ellipse cx="188" cy="100" rx="6" ry="5" fill="#313244" stroke="{OL}" stroke-width="1"/>
  <ellipse cx="188" cy="99" rx="3.5" ry="2" fill="{C['darker']}"/>

  <!-- Nose -->
  <path d="M 188,96 C 186,96 185,97 186,98 C 187,99 188,99 188,99
           C 188,99 189,99 190,98 C 191,97 190,96 188,96Z" fill="{NOSE}" stroke="{C['noseDark']}" stroke-width="0.5"/>

  <!-- Whiskers -->
  <g stroke="{DARK}" stroke-width="0.7" fill="none" opacity="0.5">
    <path d="M 192,98 Q 200,95 208,94"/>
    <path d="M 192,100 Q 202,100 210,100"/>
    <path d="M 192,102 Q 200,105 208,108"/>
  </g>
  </g>
</svg>'''

def make_tail_swish(frame):
    '''Idle pose with tail swishing. 4 frames for smooth animation.
    frame 0: tail center-left, 1: tail far-left, 2: tail center-right, 3: tail far-right'''
    cx = 105
    tails = [
        # Frame 0: center-left (gentle curve left)
        f'''<path d="M 68,170 C 52,155 35,135 25,115 C 15,95 18,75 22,65 C 26,55 34,58 33,68 C 32,78 35,95 42,115 C 49,135 60,155 66,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 22,65 C 26,55 34,58 33,68 C 30,62 26,56 22,65Z" fill="{C['white']}"/>''',
        # Frame 1: far-left (wide sweep)
        f'''<path d="M 68,170 C 45,158 20,148 5,140 C -10,132 -12,122 -6,118 C 0,114 10,120 18,130 C 26,140 42,155 64,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M -6,118 C 0,114 10,120 18,130 C 8,122 2,116 -6,118Z" fill="{C['white']}"/>''',
        # Frame 2: center-right (gentle curve right)
        f'''<path d="M 142,170 C 158,155 175,135 185,115 C 195,95 192,75 188,65 C 184,55 176,58 177,68 C 178,78 175,95 168,115 C 161,135 150,155 144,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 188,65 C 184,55 176,58 177,68 C 180,62 184,56 188,65Z" fill="{C['white']}"/>''',
        # Frame 3: far-right (wide sweep)
        f'''<path d="M 142,170 C 165,158 190,148 205,140 C 220,132 222,122 216,118 C 210,114 200,120 192,130 C 184,140 168,155 146,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 216,118 C 210,114 200,120 192,130 C 202,122 208,116 216,118Z" fill="{C['white']}"/>''',
    ]

    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  {tails[frame]}

  <!-- Back legs -->
  <path d="M 65,176 C 57,184 52,196 54,206 C 56,212 62,214 68,212" fill="{C['body']}"/>
  <path d="M 56,200 C 54,206 56,212 62,214 C 66,215 70,212 70,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(62, 212)}
  <path d="M 145,176 C 148,184 152,196 150,206 C 148,212 142,214 136,212" fill="{C['body']}"/>
  <path d="M 148,200 C 150,206 148,212 142,214 C 138,215 134,212 134,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(142, 212)}

  <!-- Body+Head+Ears silhouette (same as idle) -->
  <path d="M 65,198 C 78,202 132,202 145,198 C 153,192 155,182 155,170 C 155,160 156,148 158,132 C 162,115 164,100 156,80 Q 176,38 162,18 Q 146,34 130,58 C 120,50 90,50 80,58 Q 64,34 48,18 Q 34,38 54,80 C 46,100 48,115 52,132 C 56,148 55,160 55,170 C 55,182 57,192 65,198 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <!-- Ear inners -->
  <path d="M 58,76 Q 44,44 52,26 Q 62,40 74,62 Z" fill="white"/>
  <path d="M 152,76 Q 166,44 158,26 Q 148,40 136,62 Z" fill="white"/>

  <!-- Belly -->
  <ellipse cx="{cx}" cy="176" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front legs -->
  <path d="M 80,180 C 76,190 74,200 76,208 C 78,214 84,217 90,215" fill="{C['body']}"/>
  <path d="M 78,202 C 76,208 78,214 82,216 C 86,217 90,215 92,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(84, 215)}
  <path d="M 130,180 C 128,190 126,200 124,208 C 122,214 126,217 132,215" fill="{C['body']}"/>
  <path d="M 126,202 C 124,208 125,214 130,216 C 135,217 140,215 140,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(132, 215)}

  <!-- Muzzle -->
  <ellipse cx="{cx}" cy="120" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 77)}
  {eye(cx-23, 97, 17, 19, C['eyeAmber'], C['eyeAmberDark'])}
  {eye(cx+23, 97, 17, 19, C['eyeBlue'], C['eyeBlueDark'])}
  {nose_mouth(cx, 122)}
  {whiskers(cx, 126)}
</svg>'''

def make_jump():
    '''Mid-air jump - all four legs tucked under body'''
    cx = 105
    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(0, 20)">
  <!-- Tail streaming behind/up -->
  <path d="M 68,138 C 50,120 30,95 22,70 C 14,45 20,25 26,15 C 32,5 40,8 38,18 C 36,28 32,45 36,65 C 40,85 55,115 65,132" fill="{C['body']}"/>
  <path d="M 45,100 C 35,80 25,58 22,42 C 19,28 24,18 28,14 C 32,10 38,12 38,18 C 38,24 34,40 36,58 C 38,76 44,95 48,104" fill="none" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 26,15 C 32,5 40,8 38,18 C 36,12 30,6 26,15Z" fill="{C['white']}"/>

  <!-- All four legs tucked under body -->
  <!-- Back legs tucked -->
  <path d="M 70,172 C 62,174 58,178 60,182 C 62,186 68,186 72,184" fill="{C['body']}"/>
  {paw(66, 184)}
  <path d="M 140,172 C 148,174 152,178 150,182 C 148,186 142,186 138,184" fill="{C['body']}"/>
  {paw(144, 184)}

  <!-- Body+Head+Ears silhouette -->
  <path d="M 65,178 C 78,182 132,182 145,178 C 153,172 155,162 155,150 C 155,140 156,128 158,112 C 162,95 164,80 156,60 Q 176,18 162,-2 Q 146,14 130,38 C 120,30 90,30 80,38 Q 64,14 48,-2 Q 34,18 54,60 C 46,80 48,95 52,112 C 56,128 55,140 55,150 C 55,162 57,172 65,178 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <!-- Ear inners -->
  <path d="M 58,56 Q 44,24 52,6 Q 62,20 74,42 Z" fill="white"/>
  <path d="M 152,56 Q 166,24 158,6 Q 148,20 136,42 Z" fill="white"/>

  <!-- Belly -->
  <ellipse cx="{cx}" cy="156" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front legs tucked -->
  <path d="M 82,168 C 76,172 72,178 74,184 C 76,188 82,190 88,188" fill="{C['body']}"/>
  {paw(82, 188)}
  <path d="M 128,168 C 134,172 138,178 136,184 C 134,188 128,190 122,188" fill="{C['body']}"/>
  {paw(128, 188)}

  <!-- Muzzle -->
  <ellipse cx="{cx}" cy="100" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 57)}
  <!-- Wide eyes (excited jump) -->
  {eye(cx-23, 77, 17, 19, C['eyeAmber'], C['eyeAmberDark'])}
  {eye(cx+23, 77, 17, 19, C['eyeBlue'], C['eyeBlueDark'])}
  {nose_mouth(cx, 102)}
  {whiskers(cx, 106)}
  </g>
</svg>'''

def _path_nums(d):
    """Extract all numbers from an SVG path d-attribute string."""
    return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', d)]

def _subdivide_last_cubic(nums):
    """Split the last cubic bezier segment into two using De Casteljau at t=0.5."""
    n_segs = (len(nums) - 2) // 6
    last_idx = 2 + (n_segs - 1) * 6
    if n_segs >= 2:
        sx, sy = nums[last_idx - 2], nums[last_idx - 1]
    else:
        sx, sy = nums[0], nums[1]
    ax, ay = nums[last_idx], nums[last_idx + 1]
    bx, by = nums[last_idx + 2], nums[last_idx + 3]
    cx, cy = nums[last_idx + 4], nums[last_idx + 5]
    m_sa_x, m_sa_y = (sx + ax) / 2, (sy + ay) / 2
    m_ab_x, m_ab_y = (ax + bx) / 2, (ay + by) / 2
    m_bc_x, m_bc_y = (bx + cx) / 2, (by + cy) / 2
    m_sab_x, m_sab_y = (m_sa_x + m_ab_x) / 2, (m_sa_y + m_ab_y) / 2
    m_abc_x, m_abc_y = (m_ab_x + m_bc_x) / 2, (m_ab_y + m_bc_y) / 2
    mid_x, mid_y = (m_sab_x + m_abc_x) / 2, (m_sab_y + m_abc_y) / 2
    result = list(nums[:last_idx])
    result.extend([m_sa_x, m_sa_y, m_sab_x, m_sab_y, mid_x, mid_y])
    result.extend([m_abc_x, m_abc_y, m_bc_x, m_bc_y, cx, cy])
    return result

def _build_main_d(nums):
    """Build main tail path d-attribute from coordinate numbers."""
    parts = [f"M {int(nums[0])},{int(nums[1])}"]
    for i in range(2, len(nums), 6):
        parts.append(f"C {int(nums[i])},{int(nums[i+1])} {int(nums[i+2])},{int(nums[i+3])} {int(nums[i+4])},{int(nums[i+5])}")
    return " ".join(parts)

def _build_tip_d(nums):
    """Build tip path d-attribute from coordinate numbers (appends Z)."""
    parts = [f"M {int(nums[0])},{int(nums[1])}"]
    for i in range(2, len(nums), 6):
        parts.append(f"C {int(nums[i])},{int(nums[i+1])} {int(nums[i+2])},{int(nums[i+3])} {int(nums[i+4])},{int(nums[i+5])}")
    return " ".join(parts) + "Z"

def _lerp_tail(main_a, tip_a, main_b, tip_b):
    """Interpolate between two tail configurations by averaging coordinates.
    Normalizes segment counts via De Casteljau subdivision when needed."""
    nums_a = _path_nums(main_a)
    nums_b = _path_nums(main_b)
    while len(nums_a) < len(nums_b):
        nums_a = _subdivide_last_cubic(nums_a)
    while len(nums_b) < len(nums_a):
        nums_b = _subdivide_last_cubic(nums_b)
    avg_main = [round((a + b) / 2) for a, b in zip(nums_a, nums_b)]
    tnums_a = _path_nums(tip_a)
    tnums_b = _path_nums(tip_b)
    avg_tip = [round((a + b) / 2) for a, b in zip(tnums_a, tnums_b)]
    return _build_main_d(avg_main), _build_tip_d(avg_tip)

def make_tail_swish_b(frame):
    '''Idle pose with 8-frame tail swish variant B.
    Adds intermediate positions between the 4 original frames for smoother animation.
    frame 0: center-left, 1: quarter-left, 2: far-left, 3: returning from left,
    4: center-right, 5: quarter-right, 6: far-right, 7: returning from right'''
    cx = 105
    orig_main = [
        "M 68,170 C 52,155 35,135 25,115 C 15,95 18,75 22,65 C 26,55 34,58 33,68 C 32,78 35,95 42,115 C 49,135 60,155 66,166",
        "M 68,170 C 45,158 20,148 5,140 C -10,132 -12,122 -6,118 C 0,114 10,120 18,130 C 26,140 42,155 64,166",
        "M 142,170 C 158,155 175,135 185,115 C 195,95 192,75 188,65 C 184,55 176,58 177,68 C 178,78 175,95 168,115 C 161,135 150,155 144,166",
        "M 142,170 C 165,158 190,148 205,140 C 220,132 222,122 216,118 C 210,114 200,120 192,130 C 184,140 168,155 146,166",
    ]
    orig_tip = [
        "M 22,65 C 26,55 34,58 33,68 C 30,62 26,56 22,65Z",
        "M -6,118 C 0,114 10,120 18,130 C 8,122 2,116 -6,118Z",
        "M 188,65 C 184,55 176,58 177,68 C 180,62 184,56 188,65Z",
        "M 216,118 C 210,114 200,120 192,130 C 202,122 208,116 216,118Z",
    ]
    tails = []
    for i in range(8):
        if i % 2 == 0:
            main_d = orig_main[i // 2]
            tip_d = orig_tip[i // 2]
        else:
            idx_a = i // 2
            idx_b = (i // 2 + 1) % 4
            main_d, tip_d = _lerp_tail(orig_main[idx_a], orig_tip[idx_a],
                                        orig_main[idx_b], orig_tip[idx_b])
        tails.append(f'''<path d="{main_d}" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="{tip_d}" fill="{C['white']}"/>''')

    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  {tails[frame]}

  <!-- Back legs -->
  <path d="M 65,176 C 57,184 52,196 54,206 C 56,212 62,214 68,212" fill="{C['body']}"/>
  <path d="M 56,200 C 54,206 56,212 62,214 C 66,215 70,212 70,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(62, 212)}
  <path d="M 145,176 C 148,184 152,196 150,206 C 148,212 142,214 136,212" fill="{C['body']}"/>
  <path d="M 148,200 C 150,206 148,212 142,214 C 138,215 134,212 134,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(142, 212)}

  <!-- Body+Head+Ears silhouette (same as idle) -->
  <path d="M 65,198 C 78,202 132,202 145,198 C 153,192 155,182 155,170 C 155,160 156,148 158,132 C 162,115 164,100 156,80 Q 176,38 162,18 Q 146,34 130,58 C 120,50 90,50 80,58 Q 64,34 48,18 Q 34,38 54,80 C 46,100 48,115 52,132 C 56,148 55,160 55,170 C 55,182 57,192 65,198 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <!-- Ear inners -->
  <path d="M 58,76 Q 44,44 52,26 Q 62,40 74,62 Z" fill="white"/>
  <path d="M 152,76 Q 166,44 158,26 Q 148,40 136,62 Z" fill="white"/>

  <!-- Belly -->
  <ellipse cx="{cx}" cy="176" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front legs -->
  <path d="M 80,180 C 76,190 74,200 76,208 C 78,214 84,217 90,215" fill="{C['body']}"/>
  <path d="M 78,202 C 76,208 78,214 82,216 C 86,217 90,215 92,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(84, 215)}
  <path d="M 130,180 C 128,190 126,200 124,208 C 122,214 126,217 132,215" fill="{C['body']}"/>
  <path d="M 126,202 C 124,208 125,214 130,216 C 135,217 140,215 140,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(132, 215)}

  <!-- Muzzle -->
  <ellipse cx="{cx}" cy="120" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 77)}
  {eye(cx-23, 97, 17, 19, C['eyeAmber'], C['eyeAmberDark'])}
  {eye(cx+23, 97, 17, 19, C['eyeBlue'], C['eyeBlueDark'])}
  {nose_mouth(cx, 122)}
  {whiskers(cx, 126)}
</svg>'''

# Generate all
for name, gen in [('cat_idle', make_idle), ('cat_sit', make_sit), ('cat_stretch', make_stretch), ('cat_jump', make_jump)]:
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w') as f:
        f.write(gen())
    print(f'{name}: OK ({os.path.getsize(path)} bytes)')

for frame in [0, 1]:
    name = f'cat_walk{frame+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w') as f:
        f.write(make_walk(frame))
    print(f'{name}: OK ({os.path.getsize(path)} bytes)')

for frame in range(4):
    name = f'cat_tail_swish{frame+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w') as f:
        f.write(make_tail_swish(frame))
    print(f'{name}: OK ({os.path.getsize(path)} bytes)')


# === Variant B: 8-frame tail swish (interpolated) ===

def make_tail_swish_b(frame):
    '''8-frame tail swish. Even frames match original 4; odd frames are interpolated.'''
    cx = 105
    tails_b = [
        # Frame 0: center-left (= original 0)
        f'''<path d="M 68,170 C 52,155 35,135 25,115 C 15,95 18,75 22,65 C 26,55 34,58 33,68 C 32,78 35,95 42,115 C 49,135 60,155 66,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 22,65 C 26,55 34,58 33,68 C 30,62 26,56 22,65Z" fill="{C['white']}"/>''',
        # Frame 1: quarter-left (between center-left and far-left)
        f'''<path d="M 68,170 C 48,156 28,142 15,128 C 2,114 3,98 8,92 C 13,86 22,89 26,99 C 30,109 38,125 53,141 C 55,148 62,158 65,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 8,92 C 13,86 22,89 26,99 C 19,92 14,87 8,92Z" fill="{C['white']}"/>''',
        # Frame 2: far-left (= original 1)
        f'''<path d="M 68,170 C 45,158 20,148 5,140 C -10,132 -12,122 -6,118 C 0,114 10,120 18,130 C 26,140 42,155 64,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M -6,118 C 0,114 10,120 18,130 C 8,122 2,116 -6,118Z" fill="{C['white']}"/>''',
        # Frame 3: returning from left (between far-left and center-right)
        f'''<path d="M 105,170 C 95,155 82,142 95,128 C 92,114 90,98 91,92 C 92,86 98,84 100,94 C 102,104 100,125 105,141 C 108,150 106,160 105,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 91,92 C 92,86 98,84 100,94 C 96,88 93,84 91,92Z" fill="{C['white']}"/>''',
        # Frame 4: center-right (= original 2)
        f'''<path d="M 142,170 C 158,155 175,135 185,115 C 195,95 192,75 188,65 C 184,55 176,58 177,68 C 178,78 175,95 168,115 C 161,135 150,155 144,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 188,65 C 184,55 176,58 177,68 C 180,62 184,56 188,65Z" fill="{C['white']}"/>''',
        # Frame 5: quarter-right (between center-right and far-right)
        f'''<path d="M 142,170 C 162,156 182,142 195,128 C 208,114 207,98 202,92 C 197,86 188,89 184,99 C 180,109 172,125 157,141 C 155,148 148,158 145,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 202,92 C 197,86 188,89 184,99 C 191,92 196,87 202,92Z" fill="{C['white']}"/>''',
        # Frame 6: far-right (= original 3)
        f'''<path d="M 142,170 C 165,158 190,148 205,140 C 220,132 222,122 216,118 C 210,114 200,120 192,130 C 184,140 168,155 146,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 216,118 C 210,114 200,120 192,130 C 202,122 208,116 216,118Z" fill="{C['white']}"/>''',
        # Frame 7: returning from right (between far-right and center-left)
        f'''<path d="M 105,170 C 115,155 128,142 115,128 C 118,114 120,98 119,92 C 118,86 112,84 110,94 C 108,104 110,125 105,141 C 102,150 104,160 105,166" fill="{C['body']}" stroke="{OL}" stroke-width="2.2"/>
  <path d="M 119,92 C 118,86 112,84 110,94 C 114,88 117,84 119,92Z" fill="{C['white']}"/>''',
    ]

    return f'''<svg viewBox="0 0 210 225" xmlns="http://www.w3.org/2000/svg">
  <!-- Tail -->
  {tails_b[frame]}

  <!-- Back legs -->
  <path d="M 65,176 C 57,184 52,196 54,206 C 56,212 62,214 68,212" fill="{C['body']}"/>
  <path d="M 56,200 C 54,206 56,212 62,214 C 66,215 70,212 70,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(62, 212)}
  <path d="M 145,176 C 148,184 152,196 150,206 C 148,212 142,214 136,212" fill="{C['body']}"/>
  <path d="M 148,200 C 150,206 148,212 142,214 C 138,215 134,212 134,208" fill="none" stroke="{OL}" stroke-width="1.8"/>
  {paw(142, 212)}

  <!-- Body+Head+Ears silhouette (same as idle) -->
  <path d="M 65,198 C 78,202 132,202 145,198 C 153,192 155,182 155,170 C 155,160 156,148 158,132 C 162,115 164,100 156,80 Q 176,38 162,18 Q 146,34 130,58 C 120,50 90,50 80,58 Q 64,34 48,18 Q 34,38 54,80 C 46,100 48,115 52,132 C 56,148 55,160 55,170 C 55,182 57,192 65,198 Z" fill="{C['body']}" stroke="{OL}" stroke-width="2.5" stroke-linejoin="round"/>

  <!-- Ear inners -->
  <path d="M 58,76 Q 44,44 52,26 Q 62,40 74,62 Z" fill="white"/>
  <path d="M 152,76 Q 166,44 158,26 Q 148,40 136,62 Z" fill="white"/>

  <!-- Belly -->
  <ellipse cx="{cx}" cy="176" rx="34" ry="14" fill="{C['light']}"/>

  <!-- Front legs -->
  <path d="M 80,180 C 76,190 74,200 76,208 C 78,214 84,217 90,215" fill="{C['body']}"/>
  <path d="M 78,202 C 76,208 78,214 82,216 C 86,217 90,215 92,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(84, 215)}
  <path d="M 130,180 C 128,190 126,200 124,208 C 122,214 126,217 132,215" fill="{C['body']}"/>
  <path d="M 126,202 C 124,208 125,214 130,216 C 135,217 140,215 140,210" fill="none" stroke="{OL}" stroke-width="2"/>
  {paw(132, 215)}

  <!-- Muzzle -->
  <ellipse cx="{cx}" cy="120" rx="24" ry="15" fill="{C['white']}"/>
  {heart(cx, 77)}
  {eye(cx-23, 97, 17, 19, C['eyeAmber'], C['eyeAmberDark'])}
  {eye(cx+23, 97, 17, 19, C['eyeBlue'], C['eyeBlueDark'])}
  {nose_mouth(cx, 122)}
  {whiskers(cx, 126)}
</svg>'''

for frame in range(8):
    name = f'cat_tail_swish_b{frame+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w') as f:
        f.write(make_tail_swish_b(frame))
    print(f'{name}: OK ({os.path.getsize(path)} bytes)')

for frame in range(8):
    name = f'cat_tail_swish_b{frame+1}'
    path = rf'C:\Software\copilot-cat\assets\{name}.svg'
    with open(path, 'w') as f:
        f.write(make_tail_swish_b(frame))
    print(f'{name}: OK ({os.path.getsize(path)} bytes)')
