from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
root=Path(__file__).resolve().parents[1]/"PerfectTiming/Resources/Assets.xcassets"
size=1024
base=Image.new("RGB",(size,size),(3,7,24))
glow=Image.new("RGBA",(size,size),(0,0,0,0)); g=ImageDraw.Draw(glow)
for radius,alpha,width in [(330,42,70),(280,90,48),(230,255,38)]:
 box=(size//2-radius,size//2-radius,size//2+radius,size//2+radius)
 g.arc(box,310,390,fill=(0,220,255,alpha),width=width)
glow=glow.filter(ImageFilter.GaussianBlur(18)); base=Image.alpha_composite(base.convert("RGBA"),glow)
d=ImageDraw.Draw(base)
d.ellipse((232,232,792,792),outline=(0,220,255,130),width=30)
d.arc((232,232,792,792),310,390,fill=(65,245,255,255),width=50)
d.rounded_rectangle((500,205,524,512),radius=12,fill=(255,255,255,255))
d.ellipse((480,480,544,544),fill=(255,255,255,255))
base.convert("RGB").save(root/"AppIcon.appiconset/AppIcon-1024.png",quality=100)
for scale,pixels in [(1,180),(2,360),(3,540)]:
 image=base.resize((pixels,pixels),Image.Resampling.LANCZOS)
 suffix="" if scale==1 else f"@{scale}x"
 image.save(root/f"LaunchLogo.imageset/LaunchLogo{suffix}.png")
print("generated",root)
