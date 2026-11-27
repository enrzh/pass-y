#!/usr/bin/env python3
"""Writes a screenshot as an opaque 8-bit sRGB PNG (App Store Connect rejects alpha). Usage: flatten_png.py <in> <out>

The pixel size stays as it is. An embedded wide-gamut profile (simulator screenshots are Display P3) is converted to
sRGB.
"""
import io
import sys

from PIL import Image, ImageCms

image = Image.open(sys.argv[1])
profile = image.info.get("icc_profile")
rgb = image.convert("RGB")
if profile:
    rgb = ImageCms.profileToProfile(rgb, ImageCms.ImageCmsProfile(io.BytesIO(profile)),
                                    ImageCms.createProfile("sRGB"), outputMode="RGB")
    rgb.info.pop("icc_profile", None)
rgb.save(sys.argv[2], "PNG")
print(sys.argv[2], rgb.size, rgb.mode)
