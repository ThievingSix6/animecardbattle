BACKGROUND & SPLASH IMAGES
==========================

Drop images here to reskin screens. All optional.

  menu_bg.png     Backdrop for every 2D screen (menu, collection, packs...)
                  A dark scrim is drawn over it automatically so text
                  stays readable, so a busy image is fine.

  lobby_sky.png   360-degree panorama used as the sky in the 3D lobby.
                  Needs to be an equirectangular image (2:1 ratio, e.g.
                  4096x2048). Search "free HDRI panorama" - polyhaven.com
                  has good ones and they're CC0.

Per-screen backdrops: any screen script can override background_image()
and return a different filename from this folder.
