extern void *OBJC_CLASS_$_NSDateInterval __attribute__((weak_import));

int revenant_weak_probe(void) {
    return OBJC_CLASS_$_NSDateInterval != 0;
}
