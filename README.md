# Dynamic-Cel-Shader-for-Reshade

This shader is a modification of Prod80's Correct Contrast (https://github.com/prod80/prod80-ReShade-Repository) and Matsilagi's Reshade port of the MMJCelShader originally made for Retroarch (https://github.com/Matsilagi/RSRetroArch).
    
The shader scans for the overall whitepoint and blackpoint of the current frame and uses those values as reference for compressing the luminance values of each individual pixel in order to mimic the banded look of cel shading.
    
The shader has several customization options including saturation, number of shades/bands, shader strength, and outline strength.

Demonstration images coming soon.
