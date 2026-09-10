BACKGROUND & SPLASH IMAGES
==========================

Drop images here to reskin screens. All optional.

  title.png       The splash behind the title screen. Full-bleed, and
                  it drifts very slowly, so leave a little slack around
                  the edges of anything important. The title screen
                  assumes this image already has the game's name painted
                  into it and draws no text over it - set FORCE_WORDMARK
                  to true in scripts/screens/title_screen.gd if you want
                  the type as well.
                  Also accepted: splash.png, title_bg.png. With none of
                  those, menu_bg.png is used.

  logo.png        Optional wordmark drawn over the splash on the title
                  screen. Supply this and it is used instead of text.
                  Also accepted: wordmark.png, title_logo.png.

  menu_bg.png     Backdrop for every 2D screen (menu, collection, packs...)
                  A dark scrim is drawn over it automatically so text
                  stays readable, so a busy image is fine.

  lobby_sky.png   360-degree panorama used as the sky in the 3D lobby.
                  Needs to be an equirectangular image (2:1 ratio, e.g.
                  4096x2048). Search "free HDRI panorama" - polyhaven.com
                  has good ones and they're CC0.

Per-screen backdrops: any screen script can override background_image()
and return a different filename from this folder.
