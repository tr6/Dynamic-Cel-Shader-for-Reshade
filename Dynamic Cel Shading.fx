/*
    Description : Dynamic Cel Shading for Reshade https://reshade.me/
    Author      : Tyler Ross
    
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

namespace pd80_correctcontrast
{
    //// PREPROCESSOR DEFINITIONS ///////////////////////////////////////////////////

    //// UI ELEMENTS ////////////////////////////////////////////////////////////////
    uniform bool enable_fade <
        ui_text = "----------------------------------------------";
        ui_label = "Enable Time Based Fade";
        ui_tooltip = "Enable Time Based Fade";
        ui_category = "Flicker Reduction";
        //ui_category = "Global: Correct Contrasts";
        > = true;
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

    uniform float SatModify <
        ui_text = "----------------------------------------------";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 2.0;
        ui_step = 0.01;
        ui_label = "Saturation Modifier";
        > = 1.00;

	uniform float OtlModify <
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Outline Brightness";
        > = 0.20;

    uniform float ShdWeight <
        ui_text = "----------------------------------------------";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Shader Strength";
        > = 0.50;
    
    uniform int ShdLevels <
        ui_type = "drag";
        ui_min = 1;
        ui_max = 16;
        ui_step = 1;
        ui_label = "Shading Levels [CelShader]";
        > = 3;
    
        uniform float userWhite <
        ui_category = "Shading Customization";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Custom Whitepoint";
        ui_tooltip = "Keep above Custom Blackpoint. Ignored under certain conditions";
        > = 1.00;
    
    uniform float userBlack <
        ui_category = "Shading Customization";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Custom Blackpoint";
        ui_tooltip = "Keep below Custom Whitepoint. Ignored under certain conditions";
        > = 0.00;
    
    uniform bool ignoreWhite <
        ui_category = "Shading Customization";
        ui_label = "Ignore Above Custom Whitepoint";
        ui_tooltip = "Ignore Colors Brighter than Custom WhitePoint.  Setting overruled under certain conditions";
        > = false;
        
    uniform bool ignoreBlack <
        ui_category = "Shading Customization";
        ui_label = "Ignore Below Custom Blackpoint";
        ui_tooltip = "Ignore Colors Darker than Custom WhitePoint.  Setting overruled under certain conditions";
        > = false;
    
    uniform bool crushWhite <
        ui_category = "Shading Customization";
        ui_label = "Force Custom Whitepoint";
        ui_tooltip = "Overruled under certain conditions";
        > = false;
    
    uniform bool crushBlack <
        ui_category = "Shading Customization";
        ui_label = "Force Custom Blackpoint";
        ui_tooltip = "Overruled under certain conditions";
        > = false;

	uniform bool SatAdjust <
        ui_category = "Experimnetal Toggles";
        ui_label = "SatAdjust";
        > = false;
        
    uniform bool SatControl <
        ui_category = "Experimnetal Toggles";
        ui_label = "SatControl";
        > = false;
        
    uniform bool LumAdjust <
        ui_category = "Experimnetal Toggles";
        ui_label = "LumAdjust";
        > = true;

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


	//// ALTERNATE SHADING METHOD STUFF////////////////////////////////////////////////////
	float3 colorAdjust(float3 cRGB, float3 cHSLBlack, float3 cHSLWhite) 
	{
    float3 cHSL = RGB2HSL(cRGB);
	
	
	if(SatControl == true){
    cHSL.y = SatModify;
    }
	
	
	
	
    float3 BlkWhtGap = (cHSLWhite.z - cHSLBlack.z);
    float cr = BlkWhtGap / ShdLevels;
    

    // brightness modifier
    float BrtModify = mod(cHSL.z, cr);

    if(SatAdjust == true){
    if(cHSL.z > cHSLBlack.z && cHSL.z < cHSLWhite.z){
    cHSL.y += (cHSL.z * cr - BrtModify);
    }
    }
    
    if (LumAdjust == true){
    
    if(cHSL.z > cHSLBlack.z && cHSL.z < cHSLWhite.z)
    {
        cHSL.z += (cHSL.z * cr - BrtModify);
        cHSL.y *= SatModify;
        
        if(cHSL.z > cHSLWhite.z)
        {
            cHSL.z = cHSLWhite.z;
        } 
	
        if(cHSL.z < cHSLBlack.z) 
        {
            cHSL.z = cHSLBlack.z;
        }
        
    }
    
        
    if((crushWhite) && (userWhite > userBlack) && (userWhite > cHSLBlack.z))
    {
        if(cHSL.z > userWhite) {cHSL.z = userWhite;};
    }
    if((crushBlack) && (userBlack < userWhite) && (userBlack < cHSLWhite.z))
    {
        if(cHSL.z < userBlack) {cHSL.z = userBlack;};
    }
    }

	cRGB = HSL2RGB(cHSL);

    return cRGB;
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

    float4 PS_CorrectContrast(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
    {
	
        float4 color       = tex2D( ReShade::BackBuffer, texcoord );
        float4 color2      = color;
	
    
        float2 offset = float2(0.0,0.0);
        float2 offset_inv = float2(0.0,0.0);
        float2 TEX0 = texcoord.xy;
        float2 TEX1 = float2(0.0,0.0);
        float2 TEX1_INV = float2(0.0,0.0);
        float2 TEX2 = float2(0.0,0.0);
        float2 TEX2_INV = float2(0.0,0.0);
        float2 TEX3 = float2(0.0,0.0);
        float2 TEX3_INV = float2(0.0,0.0);
	
        offset = -(float2(1.0 / ReShade::ScreenSize.x, 0.0)); //XY
        offset_inv = float2(1.0 / ReShade::ScreenSize.x,0.0); //ZW
        TEX1 = TEX0 + offset;
        TEX1_INV = TEX0 + offset_inv;
	
        offset = -(float2(0.0,(1.0 / ReShade::ScreenSize.y))); //XY
        offset_inv = float2(0.0, (1.0 / ReShade::ScreenSize.y)); //ZW
    
        TEX2 = TEX0.xy + offset;
        TEX2_INV = TEX0.xy + offset_inv;
        TEX3 = TEX1.xy + offset;
        TEX3_INV = TEX1.xy + offset_inv;
	
        float3 c0 = tex2D(RetroArchSRGB, TEX3.xy).rgb;
        float3 c1 = tex2D(RetroArchSRGB, TEX2.xy).rgb;
        float3 c2 = tex2D(RetroArchSRGB, float2(TEX3_INV.x,TEX3.y)).rgb;
        float3 c3 = tex2D(RetroArchSRGB, TEX1.xy).rgb;
        float3 c4 = tex2D(RetroArchSRGB, TEX0.xy).rgb;
        float3 c5 = tex2D(RetroArchSRGB, TEX1_INV.xy).rgb;
        float3 c6 = tex2D(RetroArchSRGB, float2(TEX3.x,TEX3_INV.y)).rgb;
        float3 c7 = tex2D(RetroArchSRGB, TEX2_INV).rgb;
        float3 c8 = tex2D(RetroArchSRGB, TEX3_INV).rgb;
        float3 c9 = ((c0 + c2 + c6 + c8) * 0.15 + (c1 + c3 + c5 + c7) * 0.25 + c4) / 2.6;

        float3 o = float3(1.0,1.0,1.0); 
        float3 h = float3(0.05,0.05,0.05); 
        float3 hz = h; 
        float k = 0.005; 
        float kz = 0.007; 
        float i = 0.0;

        float3 cz = (c9 + h) / (dot(o, c9) + k);

        hz = (cz - ((c0 + h) / (dot(o, c0) + k))); i  = kz / (dot(hz, hz) + kz);
        hz = (cz - ((c1 + h) / (dot(o, c1) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c2 + h) / (dot(o, c2) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c3 + h) / (dot(o, c3) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c5 + h) / (dot(o, c5) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c6 + h) / (dot(o, c6) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c7 + h) / (dot(o, c7) + k))); i += kz / (dot(hz, hz) + kz);
        hz = (cz - ((c8 + h) / (dot(o, c8) + k))); i += kz / (dot(hz, hz) + kz);
	
        
        i /= 8.0; 
        i = pow(i, 0.75);

        if(i < OtlModify) { i = OtlModify; }
	
	
	
        if (ShdWeight > 0){
        
            float3 minValue    = tex2D( samplerDS_1x1, float2( texcoord.x / 4.0f, texcoord.y )).xyz;
            float3 maxValue    = tex2D( samplerDS_1x1, float2(( texcoord.x + 2.0f ) / 4.0f, texcoord.y )).xyz;
            // Black/White Point Change
            float adjBlack     = min( min( minValue.x, minValue.y ), minValue.z );    
            float adjWhite     = max( max( maxValue.x, maxValue.y ), maxValue.z );
            float3 cHSLBlack = RGB2HSL(adjBlack);
            float3 cHSLWhite = RGB2HSL(adjWhite);
            
            if(userBlack > cHSLBlack.z && userBlack < userWhite && userBlack < cHSLWhite.z && ignoreBlack == 1){
                cHSLBlack.z = userBlack;
                adjBlack = HSL2RGB(cHSLBlack);
            }
            		
            if (userWhite < cHSLWhite.z && userWhite > userBlack && userWhite > cHSLBlack.z && ignoreWhite == 1){
                cHSLWhite.z = userWhite;
                adjWhite = HSL2RGB(cHSLWhite);
            }
                       
        
 
        color = lerp((color2), colorAdjust(color, cHSLBlack, cHSLWhite), ShdWeight);
            
        }

    color = color * i;

    return float4( color.xyz, 1.0f );
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
	technique Dynamic_Cel_Shading
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