# Changelog

## [1.1.0] – 2026-05-10

### Changed
- Menu bar now shows actual color swatches next to the hex values (Ø average, ◆ dominant) instead of brightness-based emoji approximations (⬛/⬜/🔲)
- Removed `ColorAnalyzer.brightnessBlock()` — replaced by inline SwiftUI `Label` with a colored `RoundedRectangle`

## [1.0.0] – 2026-03-29

### Added
- Initial release
- Dominant & average color extraction (Median-Cut algorithm)
- 5-zone analysis (center, top, bottom, left, right)
- Smooth color transitions
- Home Assistant webhook integration
- MQTT publish support (pure `Network.framework`, no external dependencies)
- Dynamic menu bar icon with color dot
- Screensaver & screen lock detection
- Wake-from-sleep trigger
- Launch at Login (SMAppService)
