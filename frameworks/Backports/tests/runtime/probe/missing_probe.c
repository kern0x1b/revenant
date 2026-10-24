extern void *OBJC_CLASS_$_RevenantNoSuchClass __attribute__((weak_import));

int revenant_missing_probe(void) {
    return OBJC_CLASS_$_RevenantNoSuchClass != 0;
}
