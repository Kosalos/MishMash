#pragma once
#include <simd/simd.h>

#define NUM_FUNCTION 4
#define MAX_GRAMMER 12

typedef struct {
    int index;
    float xT,yT;
    float xS,yS;
    float rot;
    float unused[4];
} Function;

typedef struct {
    int version;
    int xSize,ySize;
    float xmin,xmax,dx;
    float ymin,ymax,dy;
    
    char grammar[MAX_GRAMMER+1];
    float stripeDensity;
    float escapeRadius;
    float multiplier;
    float contrast;
    float R;
    float G;
    float B;
    
    Function function[NUM_FUNCTION];
    
    float future[10];
} Control;

// Swift access to arrays in Control
#ifndef __METAL_VERSION__

void controlRandom(void);
void controlRandomGrammar(void);

void setControlPointer(Control *ptr);
void setGrammarCharacter(int index, char chr);
int  getGrammarCharacter(int index);

int* funcIndexPointer(int fIndex);
int funcIndex(int fIndex);
float* funcXtPointer(int fIndex);
float* funcYtPointer(int fIndex);
float* funcXsPointer(int fIndex);
float* funcYsPointer(int fIndex);
float* funcRotPointer(int fIndex);
int isFunctionActive(int index);

#endif
