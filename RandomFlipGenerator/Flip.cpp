#include <stdlib.h>     // srand, rand
#include <time.h>
#include "Flip.h"

static bool SEED = []()-> bool {srand (time(0)); return true;}();
//static long RAND = 1<<30;
//==================================================================
Flip::Flip(int bias) {part=(int)(RAND_MAX * (bias/100.0));}
int   Flip::Invoke() {return rand()<part;}
//==================================================================
Roll::Roll(int upto)        : min( 0 ), span(upto)      {}
Roll::Roll(int min, int max): min(min), span(max-min+1) {}  // inclusive: [both,,ends] thus +1
int   Roll::Invoke() {return (rand()%span)+min;}          // add the min to ensure at least that
//==================================================================
