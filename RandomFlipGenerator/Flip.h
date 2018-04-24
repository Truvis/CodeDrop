#ifndef FLIP_H
#define FLIP_H
/*========================================================================*
    Flip coin;          coin()      // fairness  50% true/false
         bias(90);      bias()      // weighted  90% true

    Roll slot(100);     roll()      // yields [0~99]
         kids(1,10);    kids()      // yields [1~10]
*========================================================================*/
class Flip
{
    public:
        Flip(int bias=50);          /// Flips evenly or with a bias
        virtual~Flip() {}

        int  Invoke();          /// flip() yields according to your bias: 90%true 10%false

    protected:
        int part;
};
//=============================================================================================
class Roll
{
    public:
        Roll(int upto);             // yields an int ==> 0 up to but not including UPTO
        Roll(int min, int max);     // yields [min ~ max] includes both ends
        virtual~Roll() {}

        int  Invoke();          // roll() yields an int fitting within range given

    protected:
        int min, span;
};
//=============================================================================================
#endif // FLIP_H
