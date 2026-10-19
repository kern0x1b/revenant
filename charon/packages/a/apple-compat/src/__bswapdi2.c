unsigned long long __bswapdi2(unsigned long long value)
{
    unsigned int high = (unsigned int)(value >> 32), low = (unsigned int)value;
    high = (high >> 24) | ((high >> 8) & 0xFF00) | ((high << 8) & 0xFF0000) | (high << 24);
    low = (low >> 24) | ((low >> 8) & 0xFF00) | ((low << 8) & 0xFF0000) | (low << 24);
    return ((unsigned long long)low << 32) | high;
}
