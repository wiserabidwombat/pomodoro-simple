"""Draws Steady's app icon: a three-quarters progress ring in coral on black,
with a tomato's leaves and stem where the ring starts (a nod to the Pomodoro
technique's tomato timer).

Writes icon-light.png (default), icon-dark.png (transparent background, for
iOS 18 Dark icons) and icon-tinted.png (white on black, for Tinted icons),
all 1024x1024. Save the default as RGB (no alpha) and the tinted one as
grayscale, then copy them into Pomodoro/Assets.xcassets/AppIcon.appiconset
(icon-1024.png, icon-1024-dark.png, icon-1024-tinted.png) and the default into
PomodoroWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png.
Requires: pip install cairosvg
"""
import cairosvg, sys
CORAL="#FF4F4F"; LEAF="#2E7D32"; LEAF_DARK="#1B4D1E"

def leaf(base, tip, bulge):
    bx,by=base; tx,ty=tip
    mx,my=(bx+tx)/2,(by+ty)/2
    dx,dy=tx-bx,ty-by
    L=(dx*dx+dy*dy)**.5; nx,ny=-dy/L,dx/L
    c1=(mx+nx*bulge, my+ny*bulge); c2=(mx-nx*bulge, my-ny*bulge)
    return f"M {bx} {by} Q {c1[0]:.1f} {c1[1]:.1f} {tx} {ty} Q {c2[0]:.1f} {c2[1]:.1f} {bx} {by} Z"

def svg(variant="light", size=1024):
    cx,cy,r,w=512,530,292,112
    top=cy-r
    bg = {"light":"#000000","dark":"none","tinted":"#000000"}[variant]
    if variant=="tinted":
        ring, track, lf, lfd = "#FFFFFF", "rgba(255,255,255,0.22)", "#BDBDBD", "#8A8A8A"
    else:
        ring, track, lf, lfd = CORAL, "rgba(255,79,79,0.20)", LEAF, LEAF_DARK
    endx, endy = cx-r, cy   # 9 o'clock: three-quarters done, clockwise from 12
    parts=[]
    if bg!="none": parts.append(f'<rect width="1024" height="1024" fill="{bg}"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{track}" stroke-width="{w}"/>')
    parts.append(f'<path d="M {cx} {top} A {r} {r} 0 1 1 {endx} {endy}" fill="none" stroke="{ring}" stroke-width="{w}" stroke-linecap="round"/>')
    # calyx: two leaves and a short stem sprouting from the ring's starting cap
    base_y = top-8
    parts.append(f'<path d="{leaf((cx-8, base_y), (cx-158, base_y-36), 50)}" fill="{lf}"/>')
    parts.append(f'<path d="{leaf((cx+8, base_y), (cx+158, base_y-36), 50)}" fill="{lf}"/>')
    parts.append(f'<path d="M {cx} {base_y+4} C {cx} {base_y-26} {cx+6} {base_y-46} {cx+22} {base_y-66}" fill="none" stroke="{lfd}" stroke-width="32" stroke-linecap="round"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">{"".join(parts)}</svg>'

for v in ["light","dark","tinted"]:
    cairosvg.svg2png(bytestring=svg(v).encode(), write_to=f"icon-{v}.png", output_width=1024, output_height=1024)
print("done")
