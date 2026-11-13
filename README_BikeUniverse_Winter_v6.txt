Bike Universe Winter v6 - Test Package

1. Test BikeUniverse_Winter_v6.lua first in the same environment you used for v5.
2. Keep the .txt copy as a readable backup.
3. This package contains readable source code, not an obfuscated/protected release.
4. The engine, visual effects, and UI are statically reviewed, but a live Roblox test is still required.

Changes in v6:
- Replaced the detached key icon and glossy access panel with a simpler full-width key field.
- Reduced intro/menu snow particles and throttled their position updates to 24 Hz.
- Reduced the intro blur strength.
- Throttled the main automation loop to 20 Hz.
- Removed the full Workspace descendant scan from re-seat lookup.
- Reduced teleport velocity cleanup to the vehicle assembly root.
- Improved Anti-AFK key-send error handling and added a throttled VirtualUser keep-alive path.
- Kept custom Anti-AFK key presses off the bike seat to avoid unwanted dismounts.
