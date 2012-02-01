/* $Id: shoot_boundary.c 4583 2011-12-06 16:03:01Z john $ */
/* (c) John Ashburner (2011) */

#include "mex.h"
#include "shoot_boundary.h"

/* Neumann boundary condition */
static mwSignedIndex neumann_boundary(mwSignedIndex i, mwSize m)
{
    mwSignedIndex m2 = m*2;
    i = (i<0) ? m2-((-i-1)%m2)-1 : (i%m2);
    return((m<=i)? m2-i-1: i);
}

static mwSignedIndex circulant_boundary(mwSignedIndex i, mwSize m)
{
    return((i>=0) ? i%((signed)m) : (((signed)m)+i%((signed)m))%(signed)m);
}

mwSignedIndex (*bound)() = circulant_boundary;
static int bound_type = BOUND_CIRCULANT;

void set_bound(int t)
{
    bound_type = t;
    if (t==BOUND_CIRCULANT)
        bound = circulant_boundary;
    else if (t==BOUND_NEUMANN)
        bound = neumann_boundary;
    else
        mexErrMsgTxt("Undefined boundary condition.");
}

int get_bound()
{
    return(bound_type);
}
