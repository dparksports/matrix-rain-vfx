# Native Matrix Mac App

This is a native macOS application that replicates the Matrix digital rain effect.
It uses SwiftUI and Canvas for rendering, and runs in a floating, transparent window.

## How to Run

1. Open the project folder in Terminal.
2. Run the following command:
   ```bash
   swift run MatrixApp
   ```

## Features

- **Native Performance**: Uses SwiftUI Canvas (Metal-accelerated).
- **Floating Window**: Stays on top of other windows.
- **Transparent Background**: Only the code is visible.
- **Authentic Logic**: Implements the "fixed grid, moving illumination" technique used in the original web version.
- **Custom Font**: Uses the `Matrix-Code` font for authentic glyphs.

## Customization

You can modify `Sources/MatrixApp/MatrixView.swift` to adjust:
- `fontSize`: Size of the characters.
- `speed`: Speed of the rain.
- `tailLength`: Length of the trails.
- `color`: Color of the rain (currently standard Matrix green).
