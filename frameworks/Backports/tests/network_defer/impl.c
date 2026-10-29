static char sentinel;

void *RevenantImpl_nw_parameters_create(void)
{
    return &sentinel;
}

const void *RevenantDeferSentinel(void)
{
    return &sentinel;
}
