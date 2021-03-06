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
        ui_tooltip = "Might overdarken image. Set to 1.00 to disable.";
        > = 1.00;

    uniform float ShdWeight <
        ui_text = "----------------------------------------------";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 1.0;
        ui_step = 0.01;
        ui_label = "Shader Strength";
        > = 0.50;
    
    uniform int ShdMode <
        ui_type = "drag";
        ui_min = 1;
        ui_max = 3;
        ui_step = 1;
        ui_label = "Shading Mode";
        ui_tooltip = "1 = Dynamic Value Scale, 2 = Static Value Scale, 3 = MMJ Shading Method (Dynamic)";
        > = 2;
    
    uniform int ShdLevels <
        ui_type = "drag";
        ui_min = 1;
        ui_max = 16;
        ui_step = 1;
        ui_label = "Shading Levels [CelShader]";
        > = 5;
        
    uniform int test <
        //ui_category = "Experimental Toggles";
        ui_category = "Shading Customization";
        ui_label = "Shade Distribution";
        ui_tooltip = "0: Even Distribution 1: Weighted towards Middle Values 2: Heavy Weighting";
        ui_type = "drag";
        ui_min = 0;
        ui_max = 2;
        ui_step = 1;
        > = 1; 
        
    uniform bool test2 <
        //ui_category = "Experimental Toggles";
        ui_category = "Shading Customization";
        ui_label = "Avoid Darkening/Brightening";
        ui_tooltip = "Debug: Prevents overdarkening/overbrightening past detected blackpoint/whitepoint";
        > = true;
        
    uniform bool test3 <
        //ui_category = "Experimental Toggles";
        ui_category = "Shading Customization";
        ui_label = "Brighten Shadows/Darken Highlights";
        ui_tooltip = "Reduces Shadow and Highlight Coverage. Currently only for Shade Distribution 1";
        > = true;
        
    uniform float Steepness <
        //ui_text = "----------------------------------------------";
        ui_category = "Shading Customization";
        ui_type = "drag";
        ui_min = 0.0;
        ui_max = 10;
        ui_step = 0.1;
        ui_label = "Heavy Weighting Control Value";
        > = 1.0;
    
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
        ui_category = "Experimental Toggles";
        ui_label = "SatAdjust";
        ui_tooltip = "Adjusts saturation to match change in luminance";
        > = true;
        
    uniform bool SatControl <
        ui_category = "Experimental Toggles";
        ui_label = "SatControl";
        ui_tooltip = "Debug: Sets saturation of all pixels to the same user specified value";
        > = false;
        
    uniform bool LumAdjust <
        ui_category = "Experimental Toggles";
        ui_label = "LumAdjust";
        ui_tooltip = "Debug: Controls Luminance Adjustment";
        > = true;
    
    
    uniform float LumModify <
        //ui_text = "----------------------------------------------";
        ui_type = "drag";
        ui_min = 1.0;
        ui_max = 2.0;
        ui_step = 0.01;
        ui_label = "Lumination Modifier";
        > = 1.00;
    


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


	//// ALTERNATE SHADING METHOD STUFF////////////////////////////////////////////////////
	float3 colorAdjust(float3 cRGB, float3 cHSLBlack, float3 cHSLWhite) 
	{
    float3 cHSL = RGB2HSL(cRGB);
    float3 cHSLold = cHSL;
	
	
	if(SatControl == true){
    cHSL.y = SatModify;
    }
	
	
	
	
    float3 BlkWhtGap = (cHSLWhite.z - cHSLBlack.z);
    float cr = BlkWhtGap / ShdLevels;
    

    // brightness modifier
    float BrtModify = mod(cHSL.z, cr);


    
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
    
    
    
    if(SatAdjust == true){
        cHSL.y -= cHSLold.z - cHSL.z;
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
        
        
            //if (test2 == true || ShdMode == 1 || ShdMode == 3){
        
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
                       
        
            //}
 
            
            
        
        
        
            if(ShdMode == 1){
                float3 generateShades[16];
                float3 workingShades[16];
                    
                    
  
                    
                //fills rest of array of targeted shades up to whitepoint
                for (int j=0; j < (ShdLevels); j++){
                    generateShades[j] = adjBlack + ((adjWhite - adjBlack) / (ShdLevels - 1) * j);
                    generateShades[j] = RGB2HSL(generateShades[j]);
                }
                
                float3 cHSLColor = RGB2HSL(color.xyz);
                
                cHSLColor.z *= LumModify;
                
                
                float3 cHSLold = cHSLColor;
                    
                cHSLColor.y *= SatModify;
                if (SatControl == 1){
                    cHSLColor.y = SatModify;
                }
                    
                    
                for (int j=0; j < (ShdLevels + 1); j++){
                    workingShades[j] = adjBlack + ((adjWhite - adjBlack) / (ShdLevels) * j);
                    workingShades[j] = RGB2HSL(workingShades[j]);
                }
                    
                if (test == 0){    
                for (int j=0; j < (ShdLevels); j++){
                    int k = j + 1;
                    if ((cHSLColor.z >= workingShades[j].z) && (cHSLColor.z < workingShades[k].z)){
                        cHSLColor.z = generateShades[j].z;
                    }     
  
                    if(crushWhite){
                        if(cHSLColor.z > userWhite){
                        cHSLColor.z = userWhite;
                        }
                    }    
                    
                    if((crushBlack)){
                        if(cHSLColor.z < userBlack){
                        cHSLColor.z = userBlack;
                        }
                    }
                    
                }
                }
                
                
                if (test == 1){
                        for (int j=0; j < (ShdLevels - 1); j++){
                            int k = j + 1;
                            if ((cHSLColor.z > generateShades[j].z) && (cHSLColor.z < generateShades[k].z)){
                                if(cHSLColor.z >= (generateShades[j].z + (generateShades[k].z - generateShades[j].z)/2))
                                    cHSLColor.z = generateShades[k].z;
                                else cHSLColor.z = generateShades[j].z;
                                
                            }     
                        
                        }
                    }
                    
                    
                    if(SatAdjust == true){
                    if (cHSLold.y > 0.00){
                    cHSLColor.y -= cHSLold.z - cHSLColor.z;
                    if (cHSLColor.y == 0)
                        cHSLColor.y = 0.01;
                    }
                }
                
                
                    

                    
                    color.xyz = HSL2RGB(cHSLColor);
                    
                color = lerp((color2), (color), ShdWeight);
                
            }

            if(ShdMode == 3){
                color = lerp((color2), colorAdjust(color, cHSLBlack, cHSLWhite), ShdWeight);
            }
            
            
            
            if(ShdMode == 2){
            
                    float generateShades[16];
                    float workingShades[16];
                    
                    float Black = 0.0;
                    float White = 1.0;
                    
                    
                    if(ignoreBlack){
                        Black = userBlack;
                    }
                    if(ignoreWhite){
                        White = userWhite;
                    }
                    
                                        
                    
                    //fills rest of array of targeted shades up to whitepoint
                    /*
                    for (int j=0; j < (ShdLevels); j++){
                        generateShades[j] = Black + (((White - Black) / (ShdLevels - 1)) * j);
                    */
                    
                    for (int j=0; j < (ShdLevels); j++){
                        generateShades[j] = 0.0 + ((1.0 / (ShdLevels - 1)) * j);
                    
                    //    generateShades[j] = RGB2HSL(generateShades[j]);
                    }
                    
                    float3 cHSLColor = RGB2HSL(color.xyz);
                    
                    
                    cHSLColor.z *= LumModify;
                    
                    
                    float3 cHSLold = cHSLColor;
                    
                    cHSLColor.y *= SatModify;
                    if (SatControl == 1){
                        cHSLColor.y = SatModify;
                    }
                    
                    
                    for (int j=0; j < (ShdLevels + 1); j++){
                        workingShades[j] = Black + ((White - Black) / (ShdLevels) * j);
                    }
                    
                    
                    if (test == 0){
                        for (int j=0; j < (ShdLevels); j++){
                            int k = j + 1;
                            if ((cHSLColor.z >= workingShades[j]) && (cHSLColor.z < workingShades[k])){
                                cHSLColor.z = generateShades[j];
                            }     
                        
                        }
                    }
                    
                    if (test == 1){
                    
                        if(test3){
                        
                            float bottom = (generateShades[0] + generateShades[1])/2;
                            float top = 1 - bottom;
                    
                                if(cHSLColor.z > 0.0 && cHSLColor.z < bottom){
                                    cHSLColor.z = bottom + .01;
                                }
                                
                                
                                if(cHSLColor.z < 1.0 && cHSLColor.z > top){
                                    cHSLColor.z = top;
                                }
                                
                        }
                        
                        
                        for (int j=0; j < (ShdLevels - 1); j++){
                            int k = j + 1;
                            if ((cHSLColor.z > generateShades[j]) && (cHSLColor.z < generateShades[k])){
                                if(cHSLColor.z > (generateShades[j] + (generateShades[k] - generateShades[j])/2))
                                    cHSLColor.z = generateShades[k];
                                else cHSLColor.z = generateShades[j];
                                
                            }     
                        
                        }
                        
                        
                    
                        /*
                        int r = 0;
                    
                            for (int j=0; j < (ShdLevels - 1); j++){
                                int k = j + 1;
                                if ((cHSLColor.z > generateShades[j]) && (cHSLColor.z < generateShades[k])){
                                    if(cHSLColor.z >= (generateShades[j] + (generateShades[k] - generateShades[j])/2))
                                        if(r == 0){
                                            cHSLColor.z = generateShades[k];
                                            r = r + 1;
                                        }
                                    else {
                                        if(r == 0){
                                            cHSLColor.z = generateShades[j];
                                            r = r + 1;
                                        }
                                    }
                                }     
                        
                            }
                        */
                    }
                    
                    
                    //new shade distribution
                    if (test == 2){
                    
                        float increment = 10/ShdLevels;
                        
                        float BoundsX[16];
                        
                        
                        for(int i = 0; i < ShdLevels + 1; i++){
                            BoundsX[i] = 0 + (i*increment);
                        }
                        
                        
                        float workingShades2[16];
                        
                        
                        for(int i = 0; i < ShdLevels; i++){
                            //workingShades2[i] = (1/PI)*atan((BoundsX[i] - 5)/Steepness)+(.5);
                            workingShades2[i] = 0.32*atan((BoundsX[i] - 5)/Steepness)+(0.5);
                        }
                        
                    
                    /*
                        if(cHSLColor.z < workingShades2[0]){
                            cHSLColor.z = Black;
                        }
                        
                        if(cHSLColor.z > workingShades[ShdLevels]){
                            cHSLColor.z = White;
                        }
                    */
                    
                    int q = 0;
                    
                        for(int i = 0; i < ShdLevels - 1; i++){
                            int j = i + 1;
                            if ((cHSLColor.z >= workingShades2[i]) && (cHSLColor.z < workingShades2[j])){
                                if(q == 0){
                                    cHSLColor.z = generateShades[i];
                                    q = q + 1;
                                }
                
                            //      cHSLColor.z = 0.5;
                            //    cHSLColor.z = workingShades2[i];
                                //cHSLColor.z = (workingShades2[i] + workingShades2[j])*0.5;
                            }
                        }
                        
                        
                        if(cHSLColor.z < workingShades2[0]){
                            cHSLColor.z = 0.0;
                        }
                        
                        
                        int n = ShdLevels - 1;
                        
                        if(cHSLColor.z > workingShades2[n]){
                            cHSLColor.z = 1.0;
                        }
                        
                    
                    
                        
                    
                   
                    }
                    
                    
                    if(test == 3){
                        if(cHSLColor.z >= 0 && cHSLColor.z < .05){
                            cHSLColor.z = 0;
                        }    
                        if(cHSLColor.z >= .05 && cHSLColor.z < .15){
                            cHSLColor.z = .25;
                        }    
                        if(cHSLColor.z >= .26 && cHSLColor.z < .85){
                            cHSLColor.z = 0.5;
                        }
                        if(cHSLColor.z >= .85 && cHSLColor.z < .95){
                            cHSLColor.z = .75;
                        }
                        if(cHSLColor.z >= .95 && cHSLColor.z < 1.0){
                            cHSLColor.z = 1.0;
                        }
                    }
                
                if(test2){
                
                
                if (cHSLColor.z < cHSLBlack.z){
                    cHSLColor.z = cHSLBlack.z;
                }
                
                if (cHSLColor.z > cHSLWhite.z){
                    cHSLColor.z = cHSLWhite.z;
                }
                
                }
                
                
                if(SatAdjust == true){
                    if (cHSLold.y > 0.00){
                    cHSLColor.y -= cHSLold.z - cHSLColor.z;
                    if (cHSLColor.y == 0)
                        cHSLColor.y = 0.01;
                    }
                }
                
                color.xyz = HSL2RGB(cHSLColor);
                color = lerp((color2), (color), ShdWeight);
            
            }
            
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