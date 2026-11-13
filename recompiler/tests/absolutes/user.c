extern char absolute_value;

void *reference = &absolute_value;

int user_value(void)
{
    return reference != 0;
}
