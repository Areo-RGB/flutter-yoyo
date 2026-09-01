import os
import shutil
from PIL import Image, ImageDraw

def process_icon(input_path, res_dir, assets_dir):
    # Load input image
    img = Image.open(input_path).convert("RGBA")
    
    # Save a clean transparent/rounded high-res version for app assets
    os.makedirs(assets_dir, exist_ok=True)
    asset_logo_path = os.path.join(assets_dir, "logo.png")
    # Make rounded square logo for Flutter UI header asset
    logo_img = img.resize((512, 512), Image.Resampling.LANCZOS)
    
    mask = Image.new("L", (512, 512), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, 512, 512), radius=96, fill=255)
    logo_rounded = logo_img.copy()
    logo_rounded.putalpha(mask)
    logo_rounded.save(asset_logo_path, "PNG")
    print(f"Saved asset logo to {asset_logo_path}")

    # Mipmap sizes for Android launcher icons
    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192
    }

    # Adaptive icon sizes (108dp equivalent)
    adaptive_sizes = {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432
    }

    print("Generating launcher icons (ic_launcher.png)...")
    for folder, size in mipmap_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Square icon (ic_launcher.png)
        sq_img = img.resize((size, size), Image.Resampling.LANCZOS)
        sq_out = os.path.join(folder_path, "ic_launcher.png")
        sq_img.save(sq_out, "PNG")
        print(f"  Created {sq_out}")

    print("Generating adaptive foreground & background drawable PNGs...")
    bg_color = (23, 29, 39, 255) # Sleek dark slate #171D27
    
    for folder, size in adaptive_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Background PNG
        bg_img = Image.new("RGBA", (size, size), bg_color)
        bg_out = os.path.join(folder_path, "ic_launcher_background.png")
        bg_img.save(bg_out, "PNG")
        
        # Foreground PNG (centered yoyo with safe zone padding)
        fg_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner_size = int(size * 0.70)
        offset = (size - inner_size) // 2
        
        resized_yoyo = img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        fg_img.paste(resized_yoyo, (offset, offset))
        fg_out = os.path.join(folder_path, "ic_launcher_foreground.png")
        fg_img.save(fg_out, "PNG")
        print(f"  Created {bg_out} and {fg_out}")

if __name__ == "__main__":
    input_img = "/home/paul/.gemini/antigravity/brain/b69138bd-dc22-46b7-baa9-d93b0d44262a/yoyo_app_icon_1788254309534.jpg"
    res_directory = "/home/paul/Projects/Yo-Yo-IR1-Tracker/android/app/src/main/res"
    assets_directory = "/home/paul/Projects/Yo-Yo-IR1-Tracker/assets"
    process_icon(input_img, res_directory, assets_directory)

