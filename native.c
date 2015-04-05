/**
 * This file defines the contrib native C functions. You can access these as
 * storm.n.<function>
 * for example storm.n.hello()
 */

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lrotable.h"
#include "auxmods.h"
#include <platform_generic.h>
#include <string.h>
#include <stdint.h>
#include <interface.h>
#include <stdlib.h>
#include <libstorm.h>

/**
 * This is required for the LTR patch that puts module tables
 * in ROM
 */
#define MIN_OPT_LEVEL 2
#include "lrodefs.h"

//Include some libs as C files into this file
#include "natlib/util.c"
#include "natlib/svcd.c"
#include "natlib/led.c"
#include "natlib/analog/analog.c"

////////////////// BEGIN FUNCTIONS /////////////////////////////

int contrib_fourth_root_m1000(lua_State *L) //mandatory signature
{
    //Get param 1 from top of stack
    double val = (double) luaL_checknumber(L, 1);

    int i;
    double guess = val / 2;
    double step = val / 4;
    for (i=0;i<20;i++)
    {
        if (guess*guess*guess*guess > val)
            guess -= step;
        else
            guess += step;
        step = step / 2;
    }

    //push back a *1000 fixed point
    lua_pushnumber(L, (int)(guess*1000));
    return 1; //one return value
}

// This function takes in a single value in the range of 2048 to 4096
// and converts it into an RGB value
// The function returns three values: red, green and blue
int contrib_val2rgb(lua_State *L)
{
    int i;
    double f, p, q, t, s, v;
    int red, green, blue;
    // Get the single input
    int val = (int) luaL_checknumber(L, 1);
    int cur_level = (int) luaL_checknumber(L, 2);
    int max_level = (int) luaL_checknumber(L, 3);
    // Multiply by 6 since there are 6 different possible ranges
    // Also correcting for the ADC value that was between 2048 and 4096
    //double h = 6*(val-2048)/2048.0;
    double h = 6*cur_level/max_level;
    // Just in case the ADC value was lower
    if (h < 0) {
        h = 0.0;
    }
    s = 1.0;
    v = 255.0;
 
    // Actual color converstion algorithm starts here
    i = (int) h;
    f = h - i;            // factorial part of h
    p = (unsigned char)(v * ( 1 - s ));
    q = (unsigned char)(v * ( 1 - s * f ));
    t = (unsigned char)(v * ( 1 - s * ( 1 - f ) ));
 
    switch(i) {
        case 0:
            red = v;
            green = t;
            blue = p;
            break;
        case 1:
            red = q;
            green = v;
            blue = p;
            break;
        case 2:
            red = p;
            green = v;
            blue = t;
            break;
        case 3:
            red = p;
            green = q;
            blue = v;
            break;
        case 4:
            red = t;
            green = p;
            blue = v;
            break;
        default:        // case 5:
            red = v;
            green = p;
            blue = q;
            break;
    }
    lua_pushnumber(L, red);
    lua_pushnumber(L, green);
    lua_pushnumber(L, blue);
    return 3; //three return values
}

int contrib_run_foobar(lua_State *L)
{
    //Load a symbol "foobar" from global table
    lua_getglobal(L, "foobar"); //this is TOS now
    lua_pushnumber(L, 3); //arg1
    lua_pushnumber(L, 5); //arg2
    lua_call(L, /*args=*/ 2, /*retvals=*/ 1);
    int rv = lua_tonumber(L, -1); //-1 is TOS
    printf("from C, rv is=%d\n", rv);
    return 0; //no return values
}

int contrib_run_run_foobar(lua_State *L)
{
    //Load the contrib_run_foobar symbol
    //Could also have got this by loading global storm table
    //then loading the .n key, then getting the value

    //Note that pushlightfunction is eLua specific
    lua_pushlightfunction(L, contrib_run_foobar);
    lua_call(L, 0, 0);
    return 0;
}

int counter(lua_State *L)
{
    int val = lua_tonumber(L, lua_upvalueindex(1));
    val++;

    //Set upvalue (closure variable)
    lua_pushnumber(L, val);
    lua_replace(L, lua_upvalueindex(1));

    //return it too
    lua_pushnumber(L, val);
    return 1;
}

int contrib_makecounter(lua_State *L)
{
    lua_pushnumber(L, 0); //initial val
    lua_pushcclosure(L, &counter, 1);
    return 1; //return the closure
}

/*
 Authors: Jose Oyola, Jochem van Gaalen, Naren Vasanad
 *Creates a new LED_Strip and returns it and sets all the LEDs to 0
 *Format: size, sclk, sdo
 *Format: uint32_t, uint32_t, uint16_t
 *Return: struct LED_Strip * strip
*/
static int contrib_led_init(lua_State *L)
{
  uint16_t size = lua_tonumber(L, 1);
  uint32_t sclk = lua_tonumber(L, 2);
  uint32_t sdo  = lua_tonumber(L, 3);
  struct LED_Strip * strip = LED_init(size, sclk, sdo);
  lua_pushlightuserdata(L, strip);
  return 1;
}

/*
 Authors: Jose Oyola, Jochem van Gaalen, Naren Vasanad
 *Shows the LEDs with the colors they've been set to
 *Format: strip
 *Format: struct LED_Strip *
*/
static int contrib_led_show(lua_State *L)
{
  struct LED_Strip * strip  = lua_touserdata(L, 1);
  LED_show(strip);
  return 0;
}

/*
 Authors: Jose Oyola, Jochem van Gaalen, Naren Vasanad
 *Sets a particular LED with a color
 *Have to run show after this to actually update the colors
 *Format: strip, index, reg, green, blue
 *Format: struct LED_Strip *, uint32_t, char, char, char
*/
static int contrib_led_set(lua_State *L)
{
  struct LED_Strip * strip = lua_touserdata(L, 1);
  uint16_t index = lua_tonumber(L, 2);
  char r = lua_tonumber(L, 3);
  char g = lua_tonumber(L, 4);
  char b = lua_tonumber(L, 5);
  LED_set(strip, index, r, g, b);
  return 0;
}

void delay_led(uint16_t ticks)
{
  int i;
  for(i=0;i<ticks;i++);
}

//This is a function to test the supernight led strip
//Actual implementation is in led.c
static int contrib_led_strip_write(lua_State *L)
{
  // Initialization
  uint32_t volatile * set   = (uint32_t volatile *)(0x400E1000 + 0x0 + 0x54);
  uint32_t volatile * clear = (uint32_t volatile *)(0x400E1000 + 0x0 + 0x58);
 
  /////////////////////////////////////////////////////////////////////
  // Variables that need to be passed to this function upon abstraction
  uint32_t SCLK = 0x10000; //D2
  uint32_t SDO  = 0x1000;  //D3
 
  uint32_t nDots = 5;        // number of lights in strip  
  char dr = (0x00 & 0x1f); // red data   (0 - 31)
  char dg = (0xff & 0x1f); // green data (0 - 31)
  char db = (0x00 & 0x1f); // blue data  (0 - 31)
  //////////////////////////////////////////////////////////////////////
  
  uint32_t ticks = 50;
  char mask = 0x10; // mask for data transmission
  uint32_t i,j,k;

  *clear = SCLK;
  delay_led(ticks);
  *clear = SDO;
  delay_led(ticks);
  printf("Start of program\n");
  for(i=0; i<32; i++){
    
    // write 1 as start bit
    *set   = SCLK;
    delay_led(ticks);
    *clear = SCLK;
    delay_led(ticks);
  }
  
  for (k=0; k<nDots; k++){
    mask = 0x10;
    *set   = SDO;
    delay_led(ticks);
    *set   = SCLK;
    delay_led(ticks);
    *clear = SCLK;
    delay_led(ticks);
    // output 5 bits of color data (red, green then blue)
    for(j=0; j<5; j++){

      if((mask & db) != 0) *set = SDO;
      else *clear = SDO;
      delay_led(ticks);

      *set = SCLK;
      delay_led(ticks);
      *clear = SCLK;
      delay_led(ticks);

      mask >>= 1;
    }
    mask = 0x10;
    for(j=0; j<5; j++){

      if((mask & dr) != 0) *set = SDO;
      else *clear = SDO;
      delay_led(ticks);
     
      *set   = SCLK;
      delay_led(ticks);
      *clear = SCLK;
      delay_led(ticks);

      mask >>= 1;
    }
    mask = 0x10;
    //printf("Inside loop\n");
    for(j=0; j<5; j++){

      if((mask & dg) != 0) *set = SDO;
      else *clear = SDO;
      delay_led(ticks);

      *set   = SCLK;
      delay_led(ticks);
      *clear = SCLK;
      delay_led(ticks);

      mask >>= 1;
    }
  }
  
  // add pulse
  *clear = SDO;
  delay_led(ticks);

  for(i=0; i<nDots;i++){
    *set = SCLK;
    delay_led(ticks);
    *clear = SCLK;
    delay_led(ticks);
  }
  printf("End of program\n");
    // transport data finish
    // Delay(); // replace?
    // here add some delay, or transfer to something else, refresh after about 1/30 s
  return 0;
}

/**
 * Prints out hello world
 *
 * Lua signature: hello() -> nil
 * Maintainer: Michael Andersen <m.andersen@cs.berkeley.edu>
 */
static int contrib_hello(lua_State *L)
{
    printf("Hello world\n");
    // The number of return values
    return 0;
}

/**
 * Prints out hello world N times, X ticks apart
 *
 * N >= 1
 * Lua signature: helloX(N,X) -> 42
 * Maintainer: Michael Andersen <m.andersen@cs.berkeley.edu>
 */
static int contrib_helloX_tail(lua_State *L);
static int contrib_helloX_entry(lua_State *L)
{
    //First run of the loop, lets configure N and X
    int N = luaL_checknumber(L, 1);
    int X = luaL_checknumber(L, 2);
    int loopcounter = 0;

    //Do our job
    printf ("Hello world\n");

    //We already have these on the top of the stack, but this is
    //how you would push variables you want access to in the continuation
    //Also counting down would be more efficient, but this is an example
    lua_pushnumber(L, loopcounter + 1);
    lua_pushnumber(L, N);
    lua_pushnumber(L, X);
    //Now we want to sleep, and when we are done, invoke helloX_tail with
    //the top 3 values of the stack available as upvalues
    cord_set_continuation(L, contrib_helloX_tail, 3);
    return nc_invoke_sleep(L, X);

    //We can't do anything after a cord_invoke_* call, ever!
}
static int contrib_helloX_tail(lua_State *L)
{
    //Grab our upvalues (state passed to us from the previous func)
    int loopcounter = lua_tonumber(L, lua_upvalueindex(1));
    int N = lua_tonumber(L, lua_upvalueindex(2));
    int X = lua_tonumber(L, lua_upvalueindex(3));

    //Do our job with them
    if (loopcounter < N)
    {
        printf ("Hello world\n");
        //Again, an example, these are already at the top of
        //the stack
        lua_pushnumber(L, loopcounter + 1);
        lua_pushnumber(L, N);
        lua_pushnumber(L, X);
        cord_set_continuation(L, contrib_helloX_tail, 3);
        return nc_invoke_sleep(L, X);
    }
    else
    {
        //Base case, now we do our return
        //We promised to return the number 42
        lua_pushnumber(L, 42);
        return cord_return(L, 1);
    }
}

////////////////// BEGIN MODULE MAP /////////////////////////////
const LUA_REG_TYPE contrib_native_map[] =
{
    { LSTRKEY( "hello" ), LFUNCVAL ( contrib_hello ) },
    { LSTRKEY( "helloX" ), LFUNCVAL ( contrib_helloX_entry ) },
    { LSTRKEY( "fourth_root"), LFUNCVAL ( contrib_fourth_root_m1000 ) },
    { LSTRKEY( "val2rgb"), LFUNCVAL ( contrib_val2rgb ) },
    { LSTRKEY( "run_foobar"), LFUNCVAL ( contrib_run_foobar ) },
    { LSTRKEY( "makecounter"), LFUNCVAL ( contrib_makecounter ) },
    { LSTRKEY( "led_init"), LFUNCVAL ( contrib_led_init ) },
    { LSTRKEY( "led_show"), LFUNCVAL ( contrib_led_show ) },
    { LSTRKEY( "led_set"), LFUNCVAL ( contrib_led_set ) },


    SVCD_SYMBOLS
    ADCIFE_SYMBOLS

    /* Constants for the Temp sensor. */
    // -- Register address --
    { LSTRKEY( "TMP006_VOLTAGE" ), LNUMVAL(0x00)},
    { LSTRKEY( "TMP006_LOCAL_TEMP" ), LNUMVAL(0x01)},
    { LSTRKEY( "TMP006_CONFIG" ), LNUMVAL(0x02)},
    { LSTRKEY( "TMP006_MFG_ID" ), LNUMVAL(0xFE)},
    { LSTRKEY( "TMP006_DEVICE_ID" ), LNUMVAL(0xFF)},

    // -- Config register values
    { LSTRKEY( "TMP006_CFG_RESET" ), LNUMVAL(0x80)},
    { LSTRKEY( "TMP006_CFG_MODEON" ), LNUMVAL(0x70)},
    { LSTRKEY( "TMP006_CFG_1SAMPLE" ), LNUMVAL(0x00)},
    { LSTRKEY( "TMP006_CFG_2SAMPLE" ), LNUMVAL(0x02)},
    { LSTRKEY( "TMP006_CFG_4SAMPLE" ), LNUMVAL(0x04)},
    { LSTRKEY( "TMP006_CFG_8SAMPLE" ), LNUMVAL(0x06)},
    { LSTRKEY( "TMP006_CFG_16SAMPLE" ), LNUMVAL(0x08)},
    { LSTRKEY( "TMP006_CFG_DRDYEN" ), LNUMVAL(0x01)},
    { LSTRKEY( "TMP006_CFG_DRDY" ), LNUMVAL(0x80)},

    //The list must end with this
    { LNILKEY, LNILVAL }
};
