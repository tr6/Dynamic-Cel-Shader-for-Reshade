/*
    Description : Dynamic Cel Shading 2 for Reshade https://reshade.me/
    Author      : Tyler Ross
    
	This shader is a new version of the previous edited cel shader I made before. It uses a new posterize taken from DaoDan's ColorfulPoster shader. The original license text included below.
	
	
	///////////////////////////////////////////////////////////////////////////////
//
//ReShade Shader: ColorfulPoster
//https://github.com/Daodan317081/reshade-shaders
//
//BSD 3-Clause License
//
//Copyright (c) 2018-2019, Alexander Federwisch
//All rights reserved.
//
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions are met:
//
//* Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//* Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//* Neither the name of the copyright holder nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
///////////////////////////////////////////////////////////////////////////////
	
	
	Original text below:
	
	
    This shader is a modification of prod80's Correct Contrast
    and Matsilagi's Reshade port of the MMJCelShader originally
    made for Retroarch.
    
    The shader scans for the overall whitepoint and blackpoint of the current frame
    and uses those values as reference for compressing the luminance values of 
    each individual pixel in order to mimic the banded look of cel shading.
    
    The shader has several customization options including saturation,
    number of shades/bands, shader strength, and outline strength.
    
    
    Original headers from the original shaders used are listed below.
    Information in these headers may be outdated.
    
--------------------------------------------------------------------------------

    Description : PD80 01A Correct Contrast for Reshade https://reshade.me/
    Author      : prod80 (Bas Veth)
    License     : MIT, Copyright (c) 2020 prod80


    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    
    
    
    MMJ's Cel Shader - v1.03
----------------------------------------------------------------
-- 180403 --
This is a port of my old shader from around 2006 for Pete's OGL2 
plugin for ePSXe. It started out as a shader based on the 
"CComic" shader by Maruke. I liked his concept, but I was 
looking for something a little different in the output. 

Since the last release, I've seen some test screenshots from MAME 
using a port of my original shader and have also seen another 
port to get it working with the PCSX2 emulator. Having recently 
seen some Kingdom Hearts II and Soul Calibur 3 YouTube videos with 
my ported shader inspired me to revisit it and get it working in 
RetroArch.

As for this version (1.03), I've made a few small modifications 
(such as to remove the OGL2Param references, which were specific 
to Pete's plugin) and I added some RetroArch Parameter support, 
so some values can now be changed in real time.

Keep in mind, that this was originally developed for PS1, using
various 3D games as a test. In general, it will look better in 
games with less detailed textures, as "busy" textures will lead 
to more outlining / messy appearance. Increasing "Outline 
Brightness" can help mitigate this some by lessening the 
"strength" of the outlines.

Also (in regards to PS1 - I haven't really tested other systems 
too much yet), 1x internal resolution will look terrible. 2x 
will also probably be fairly blurry/messy-looking. For best 
results, you should probably stick to 4x or higher internal 
resolution with this shader.

Parameters:
-----------
White Level Cutoff = Anything above this luminance value will be 
    forced to pure white.

Black Level Cutoff = Anything below this luminance value will be 
    forced to pure black.

Shading Levels = Determines how many color "slices" there should 
    be (not counting black/white cutoffs, which are always 
    applied).

Saturation Modifier = Increase or decrease color saturation. 
    Default value boosts saturation a little for a more 
    cartoonish look. Set to 0.00 for grayscale.

Outline Brightness = Adjusts darkness of the outlines. At a 
    setting of 1, outlines should be disabled.

Shader Strength = Adjusts the weight of the color banding 
    portion of the shader from 0% (0.00) to 100% (1.00). At a 
    setting of 0.00, you can turn off the color banding effect 
    altogether, but still keep outlines enabled.
-----------
MMJuno

*/

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#define UI_CATEGORY_POSTERIZATION "Posterization"
#define UI_CATEGORY_COLOR "Color"
#define UI_CATEGORY_EFFECT "Effect"

namespace pd80_correctcontrast
{
    //// PREPROCESSOR DEFINITIONS ///////////////////////////////////////////////////

    //// UI ELEMENTS ////////////////////////////////////////////////////////////////
    uniform bool enable_fade <
        ui_text = "----------------------------------------------";
        ui_label = "Enable Time Based Fade";
        ui_tooltip = "Enable Time Based Fade. Supposed to reduce flicker but sometimes incorrectly adds flicker.";
        ui_category = "Flicker Reduction";
        //ui_category = "Global: Correct Contrasts";
        > = false;
    uniform bool freeze <
        ui_label = "Freeze Correction";
        ui_tooltip = "Freeze Correction";
        ui_category = "Flicker Reduction";
        //ui_category = "Global: Correct Contrasts";
        > = false;
    uniform float transition_speed <
        ui_type = "slider";
        ui_label = "Time Based Fade Speed";
        ui_tooltip = "Time Based Fade Speed";
        ui_category = "Flicker Reduction";
        //ui_category = "Global: Correct Contrasts";
        ui_min = 0.0f;
        ui_max = 1.0f;
        > = 0.5;
		
		
		
	uniform int iUILumaLevels <
		ui_type = "drag";
		ui_category = UI_CATEGORY_POSTERIZATION;
		ui_label = "Luma Posterize Levels";
		ui_min = 1; ui_max = 20;
	> = 4;

	uniform int iUIStepType <
		ui_type = "combo";
		ui_category = UI_CATEGORY_POSTERIZATION;
		ui_label = "Curve Type";
		ui_items = "Linear\0Smoothstep\0Logistic\0Sigmoid\0";
	> = 2;

	uniform float fUIStepContinuity <
		ui_type = "drag";
		ui_category = UI_CATEGORY_POSTERIZATION;
		ui_label = "Continuity";
		ui_tooltip = "Broken up <-> Connected";
		ui_min = 0.0; ui_max = 1.0;
		ui_step = 0.01;
	> = 1.0;

	uniform float fUISlope <
		ui_type = "drag";
		ui_category = UI_CATEGORY_POSTERIZATION;
		ui_label = "Slope Logistic Curve";
		ui_min = 0.0; ui_max = 40.0;
		ui_step = 0.1;
	> = 40.0;

	uniform bool iUIDebugOverlayPosterizeLevels <
		ui_category = UI_CATEGORY_POSTERIZATION;
		ui_label = "Show Posterization as Curve (Magenta)";
	> = 0;

////////////////////////// Color //////////////////////////

	uniform float fUITint <
		ui_type = "drag";
		ui_category = UI_CATEGORY_COLOR;
		ui_label = "Tint Strength";
		ui_min = 0.0; ui_max = 1.0;
	> = 0.0;

////////////////////////// Effect //////////////////////////

	uniform float fUIStrength <
		ui_type = "drag";
		ui_category = UI_CATEGORY_EFFECT;
		ui_label = "Strength";
		ui_min = 0.0; ui_max = 1.0;
	> = 1.0;
    


static const float PI = 3.141592653589793238462643383279f;


#define mod(x,y) (x-y*floor(x/y))



    //// TEXTURES ///////////////////////////////////////////////////////////////////
    texture texDS_1_Max { Width = 32; Height = 32; Format = RGBA16F; };
    texture texDS_1_Min { Width = 32; Height = 32; Format = RGBA16F; };
    texture texPrevious { Width = 4; Height = 2; Format = RGBA16F; };
    texture texDS_1x1 { Width = 4; Height = 2; Format = RGBA16F; };

    //// SAMPLERS ///////////////////////////////////////////////////////////////////
    sampler samplerDS_1_Max
    { 
        Texture = texDS_1_Max;
        MipFilter = POINT;
        MinFilter = POINT;
        MagFilter = POINT;
    };
    sampler samplerDS_1_Min
    {
        Texture = texDS_1_Min;
        MipFilter = POINT;
        MinFilter = POINT;
        MagFilter = POINT;
    };
    sampler samplerPrevious
    { 
        Texture   = texPrevious;
        MipFilter = POINT;
        MinFilter = POINT;
        MagFilter = POINT;
    };
    sampler samplerDS_1x1
    {
        Texture   = texDS_1x1;
        MipFilter = POINT;
        MinFilter = POINT;
        MagFilter = POINT;
    };
	
	
	
	sampler RetroArchSRGB { Texture = ReShade::BackBufferTex; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; SRGBTexture = true;};

    //// FUNCTIONS //////////////////////////////////////////////////////////////////
    uniform float frametime < source = "frametime"; >;

    
	float3 RGB2HCV(in float3 RGB)
    {
	RGB = saturate(RGB);
	float Epsilon = 1e-10;
    	// Based on work by Sam Hocevar and Emil Persson
    	float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    	float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    	float C = Q.x - min(Q.w, Q.y);
    	float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    	return float3(H, C, Q.x);
    }
	
	
	float3 RGB2HSL(in float3 RGB)
    {
    	float3 HCV = RGB2HCV(RGB);
    	float L = HCV.z - HCV.y * 0.5;
    	float S = HCV.y / (1.0000001 - abs(L * 2 - 1));
    	return float3(HCV.x, S, L);
    }
	
	float3 HSL2RGB(in float3 HSL)
    {
        HSL = saturate(HSL);
	//HSL.z *= 0.99;
    	float3 RGB = saturate(float3(abs(HSL.x * 6.0 - 3.0) - 1.0,2.0 - abs(HSL.x * 6.0 - 2.0),2.0 - abs(HSL.x * 6.0 - 4.0)));
    	float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
    	return (RGB - 0.5) * C + HSL.z;
    }
	
	
	
	
	
	float3 interpolate( float3 o, float3 n, float factor, float ft )
    {
        return lerp( o.xyz, n.xyz, 1.0f - exp( -factor * ft ));
    }



#define MAX_VALUE(v) max(v.x, max(v.y, v.z))

float Posterize(float x, int numLevels, float continuity, float slope, int type, float3 Black, float3 Difference) {
    float stepheight = Difference.z /*difference between white and black point*/ / numLevels;
    float stepnum = floor(x * numLevels);
    float frc = frac(x * numLevels);
    float step1 = floor(frc) * stepheight;
    float step2;

    if(type == 1)
        step2 = smoothstep(0.0, 1.0, frc) * stepheight;
    else if(type == 2)
        step2 = ((1.0 / (1.0 + exp(-slope*(frc - 0.5)))) * stepheight) + Black.z /*black point*/;
    else if(type == 3)
        step2 = (frc < 0.5 ? pow(frc, slope) * pow(2.0, slope) * 0.5 : 1.0 - pow(1.0 - frc, slope) * pow(2.0, slope) * 0.5) * stepheight;
    else
        step2 = frc * stepheight;

    return lerp(step1, step2, continuity) + stepheight * stepnum;
}

float4 RGBtoCMYK(float3 color) {
    float3 CMY;
    float K;
    K = 1.0 - max(color.r, max(color.g, color.b));
    CMY = (1.0 - color - K) / (1.0 - K);
    return float4(CMY, K);
}

float3 CMYKtoRGB(float4 cmyk) {
    return (1.0.xxx - cmyk.xyz) * (1.0 - cmyk.w);
}

float3 DrawDebugCurve(float3 background, float2 texcoord, float value, float3 color, float curveDiv) {
    float p = exp(-(BUFFER_HEIGHT/curveDiv) * length(texcoord - float2(texcoord.x, 1.0 - value)));
    return lerp(background, color, saturate(p));
}



    //// PIXEL SHADERS //////////////////////////////////////////////////////////////
    //Downscale to 32x32 min/max color matrix
    void PS_MinMax_1( float4 pos : SV_Position, float2 texcoord : TEXCOORD, out float4 minValue : SV_Target0, out float4 maxValue : SV_Target1 )
    {
        float3 currColor;
        minValue.xyz       = 1.0f;
        maxValue.xyz       = 0.0f;

        // RenderTarget size is 32x32
        float pst          = 0.03125f;    // rcp( 32 )
        float hst          = 0.5f * pst;  // half size

        // Sample texture
        float2 stexSize    = float2( BUFFER_WIDTH, BUFFER_HEIGHT );
        float2 start       = floor(( texcoord.xy - hst ) * stexSize.xy );    // sample block start position
        float2 stop        = floor(( texcoord.xy + hst ) * stexSize.xy );    // ... end position

        for( int y = start.y; y < stop.y; ++y )
        {
            for( int x = start.x; x < stop.x; ++x )
            {
                currColor    = tex2Dfetch( ReShade::BackBuffer, int4( x, y, 0, 0 )).xyz;
                // Dark color detection methods
                minValue.xyz = min( minValue.xyz, currColor.xyz );
                // Light color detection methods
                maxValue.xyz = max( currColor.xyz, maxValue.xyz );
            }
        }
        // Return
        minValue           = float4( minValue.xyz, 1.0f );
        maxValue           = float4( maxValue.xyz, 1.0f );
    }

    //Downscale to 32x32 to 1x1 min/max colors
    float4 PS_MinMax_1x1( float4 pos : SV_Position, float2 texcoord : TEXCOORD ) : SV_Target
    {
        float3 minColor; float3 maxColor;
        float3 minValue    = 1.0f;
        float3 maxValue    = 0.0f;
        //Get texture resolution
        uint SampleRes     = 32;
        float Sigma        = 0.0f;

        for( int y = 0; y < SampleRes; ++y )
        {
            for( int x = 0; x < SampleRes; ++x )
            {   
                // Dark color detection methods
                minColor     = tex2Dfetch( samplerDS_1_Min, int4( x, y, 0, 0 )).xyz;
                minValue.xyz = min( minValue.xyz, minColor.xyz );
                // Light color detection methods
                maxColor     = tex2Dfetch( samplerDS_1_Max, int4( x, y, 0, 0 )).xyz;
                maxValue.xyz = max( maxColor.xyz, maxValue.xyz );
            }
        }

        //Try and avoid some flickering
        //Not really working, too radical changes in min values sometimes
        float3 prevMin     = tex2D( samplerPrevious, float2( texcoord.x / 4.0f, texcoord.y )).xyz;
        float3 prevMax     = tex2D( samplerPrevious, float2(( texcoord.x + 2.0f ) / 4.0, texcoord.y )).xyz;
        float smoothf      = transition_speed * 4.0f + 0.5f;
        float time         = frametime * 0.001f;
        maxValue.xyz       = enable_fade ? interpolate( prevMax.xyz, maxValue.xyz, smoothf, time ) : maxValue.xyz;
        minValue.xyz       = enable_fade ? interpolate( prevMin.xyz, minValue.xyz, smoothf, time ) : minValue.xyz;
        // Freeze Correction
        maxValue.xyz       = freeze ? prevMax.xyz : maxValue.xyz;
        minValue.xyz       = freeze ? prevMin.xyz : minValue.xyz;
        // Return
        if( pos.x < 2 )
            return float4( minValue.xyz, 1.0f );
        else
            return float4( maxValue.xyz, 1.0f );
    }

    float3 PS_CorrectContrast(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
    {
	
        float4 color       = tex2D( ReShade::BackBuffer, texcoord );
		
		float3 minValue    = tex2D( samplerDS_1x1, float2( texcoord.x / 4.0f, texcoord.y )).xyz;
        float3 maxValue    = tex2D( samplerDS_1x1, float2(( texcoord.x + 2.0f ) / 4.0f, texcoord.y )).xyz;
        // Black/White Point Change
        float adjBlack     = min( min( minValue.x, minValue.y ), minValue.z );    
        float adjWhite     = max( max( maxValue.x, maxValue.y ), maxValue.z );
        float3 cHSLBlack = RGB2HSL(adjBlack);
        float3 cHSLWhite = RGB2HSL(adjWhite);
		
		float3 cHSLWBDifference = cHSLWhite - cHSLBlack;
		
	
	
	static const float3 LumaCoeff = float3(0.2126, 0.7151, 0.0721);
    /*******************************************************
        Get BackBuffer
    *******************************************************/
    float3 backbuffer = tex2D(ReShade::BackBuffer, texcoord).rgb;
	

    /*******************************************************
        Calculate chroma and luma; posterize luma
    *******************************************************/
    float luma = dot(backbuffer, LumaCoeff);
    float3 chroma = backbuffer - luma;
    float3 lumaPoster = Posterize(luma, iUILumaLevels, fUIStepContinuity, fUISlope, iUIStepType, cHSLBlack, cHSLWBDifference).rrr;

    /*******************************************************
        Color
    *******************************************************/
    float3 mask, image, colorLayer;

    //Convert RGB to CMYK, add cyan tint, set K to 0.0
    float4 backbufferCMYK = RGBtoCMYK(backbuffer);
    backbufferCMYK.xyz += float3(0.2, -0.1, -0.2);
    backbufferCMYK.w = 0.0;

    //Convert back to RGB
    mask = CMYKtoRGB(saturate(backbufferCMYK));
    
    //add luma to chroma
    image = chroma + lumaPoster;

    //Blend with 'hard light'
    colorLayer = lerp(2*image*mask, 1.0 - 2.0 * (1.0 - image) * (1.0 - mask), step(0.5, luma.r));
    colorLayer = lerp(image, colorLayer, fUITint);

    /*******************************************************
        Create result
    *******************************************************/
    float3 result = lerp(backbuffer, colorLayer, fUIStrength);

    if(iUIDebugOverlayPosterizeLevels == 1) {
        float value = Posterize(texcoord.x, iUILumaLevels, fUIStepContinuity, fUISlope, iUIStepType, cHSLBlack, cHSLWBDifference);
        result = DrawDebugCurve(result, texcoord, value, float3(1.0, 0.0, 1.0), 1.0);        
    }
        
    /*******************************************************
        Set overall strength and return
    *******************************************************/
    //return result;
	
    //color = result;
        

    //return float4( color.xyz, 1.0f );
	
	return result;
    }
		
        

    float4 PS_StorePrev( float4 pos : SV_Position, float2 texcoord : TEXCOORD ) : SV_Target
    {
        float3 minValue    = tex2D( samplerDS_1x1, float2( texcoord.x / 4.0f, texcoord.y )).xyz;
        float3 maxValue    = tex2D( samplerDS_1x1, float2(( texcoord.x + 2.0f ) / 4.0f, texcoord.y )).xyz;
        if( pos.x < 2 )
            return float4( minValue.xyz, 1.0f );
        else
            return float4( maxValue.xyz, 1.0f );
    }

    //// TECHNIQUES /////////////////////////////////////////////////////////////////
    //technique prod80_01A_RT_Correct_Contrast
	technique Dynamic_Cel_Shading2
    {
        pass prod80_pass1
        {
            VertexShader       = PostProcessVS;
            PixelShader        = PS_MinMax_1;
            RenderTarget0      = texDS_1_Min;
            RenderTarget1      = texDS_1_Max;
        }
        pass prod80_pass2
        {
            VertexShader       = PostProcessVS;
            PixelShader        = PS_MinMax_1x1;
            RenderTarget       = texDS_1x1;
        }
        pass prod80_pass3
        {
            VertexShader       = PostProcessVS;
            PixelShader        = PS_CorrectContrast;
        }
        pass prod80_pass4
        {
            VertexShader       = PostProcessVS;
            PixelShader        = PS_StorePrev;
            RenderTarget       = texPrevious;
        }
    }
}