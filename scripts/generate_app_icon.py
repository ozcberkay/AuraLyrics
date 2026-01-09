import os

def generate_app_icon():
    """Generates a modern, minimalist macOS app icon for AuraLyrics."""
    # macOS App Icon is traditionally a squircle.
    svg_content = """<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Deep, professional background gradient -->
    <linearGradient id="bg_grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#1e1e2e;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0b0b12;stop-opacity:1" />
    </linearGradient>
    
    <!-- The 'Aura' - a soft, ethereal glow -->
    <radialGradient id="aura_glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#7aa2f7;stop-opacity:0.2" />
      <stop offset="100%" style="stop-color:#7aa2f7;stop-opacity:0" />
    </radialGradient>

    <!-- Glass highlight for the squircle -->
    <linearGradient id="rim_light" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#ffffff;stop-opacity:0.15" />
      <stop offset="100%" style="stop-color:#ffffff;stop-opacity:0.02" />
    </linearGradient>

    <!-- Squircle shape clipping -->
    <clipPath id="squircle">
      <path d="M 512,0 C 826.8,0 1024,197.2 1024,512 1024,826.8 826.8,1024 512,1024 197.2,1024 0,826.8 0,512 0,197.2 197.2,0 512,0 Z" />
    </clipPath>
  </defs>

  <!-- Background Squircle with depth -->
  <path d="M 512,40 C 800,40 984,224 984,512 984,800 800,984 512,984 224,984 40,800 40,512 40,224 224,40 512,40 Z" fill="url(#bg_grad)" />
  
  <!-- Aura Glow Center -->
  <circle cx="512" cy="512" r="400" fill="url(#aura_glow)" />

  <!-- The 'Lyrics' Symbol - three floating bars of light -->
  <!-- Top bar (short) -->
  <rect x="340" y="400" width="220" height="36" rx="18" fill="white" opacity="0.4" />
  <!-- Middle bar (long - the 'current' lyric) -->
  <rect x="340" y="494" width="344" height="36" rx="18" fill="white" opacity="0.95" />
  <rect x="340" y="494" width="344" height="36" rx="18" fill="#7aa2f7" opacity="0.3">
    <animate attributeName="opacity" values="0.2;0.5;0.2" dur="4s" repeatCount="indefinite" />
  </rect>
  <!-- Bottom bar (medium) -->
  <rect x="340" y="588" width="280" height="36" rx="18" fill="white" opacity="0.4" />

  <!-- Subtle Rim/Edge Light for macOS feel -->
  <path d="M 512,41 C 800,41 983,224 983,512 983,800 800,983 512,983 224,983 41,800 41,512 41,224 224,41 512,41 Z" fill="none" stroke="url(#rim_light)" stroke-width="2" />
</svg>"""
    
    os.makedirs("assets", exist_ok=True)
    svg_path = "assets/app_icon.svg"
    with open(svg_path, "w") as f:
        f.write(svg_content)
    print(f"Successfully generated {svg_path}")

    # Convert to PNG and then .icns
    try:
        print("Converting SVG to PNG...")
        # Render SVG to PNG using qlmanage
        os.system(f"qlmanage -t -s 1024 -o assets {svg_path} && mv assets/app_icon.svg.png assets/app_icon_1024.png")
        
        print("Creating .iconset...")
        iconset_path = "assets/AppIcon.iconset"
        os.makedirs(iconset_path, exist_ok=True)
        
        base_png = "assets/app_icon_1024.png"
        sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        
        for size, name in sizes:
            os.system(f"sips -z {size} {size} {base_png} --out {iconset_path}/{name} > /dev/null 2>&1")
            
        print("Generating AppIcon.icns...")
        os.system(f"iconutil -c icns {iconset_path} -o assets/AppIcon.icns")
        
        # Cleanup
        os.system(f"rm -rf {iconset_path} {base_png}")
        print("Successfully generated assets/AppIcon.icns")
        
    except Exception as e:
        print(f"Failed to generate .icns: {e}")

if __name__ == "__main__":
    generate_app_icon()
