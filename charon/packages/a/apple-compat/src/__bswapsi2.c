unsigned int __bswapsi2(unsigned int value)
{
    return (value >> 24) | ((value >> 8) & 0xFF00) | ((value << 8) & 0xFF0000) | (value << 24);
}
