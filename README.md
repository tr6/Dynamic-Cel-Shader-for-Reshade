# Dynamic-Cel-Shader-for-Reshade

This shader is a modification of Prod80's Correct Contrast (https://github.com/prod80/prod80-ReShade-Repository) and Matsilagi's Reshade port of the MMJCelShader originally made for Retroarch (https://github.com/Matsilagi/RSRetroArch).
    
The shader scans for the overall whitepoint and blackpoint of the current frame and uses those values to create a dynamic value scale. The pixels are then adjusted to conform to that value scale. Pixels are converted to the HSL color space for processing and converted back to the RGB color space for final rendering.
    
The shader has several customization options including saturation, number of shades/bands, shader strength, and outline strength.

Use the DX9 version of the shader for injecting into DirectX9 games. DirectX9 Reshade seems to have trouble with For loops.
