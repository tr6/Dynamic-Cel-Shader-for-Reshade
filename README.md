# Dynamic-Cel-Shader-for-Reshade

This shader is a modification of Prod80's Correct Contrast (https://github.com/prod80/prod80-ReShade-Repository) and Matsilagi's Reshade port of the MMJCelShader originally made for Retroarch (https://github.com/Matsilagi/RSRetroArch).

The shader attempts to achieve a faux cel shading look by compressing the luma values of each pixel into a smaller user specified number of values. The overall whitepoint and blackpoint are taken into account depending on user settings and used to prevent overdarkening and overbrightening of pixels in order to preserve some of the game's original look.
    
The shader has several customization options including saturation, number of shades/bands, shader strength, etc.

DirectX 9 Games require enabling Reshade's performance mode for the shader to compile.
