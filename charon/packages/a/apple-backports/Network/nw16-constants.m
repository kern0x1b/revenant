/*
 * NW_ALL_PATHS, the path index that stands for every path of a connection.
 *
 * The SDK declares it as a symbol and a macro over it, and the macro is what a program writes, so
 * what is here is the symbol: the largest a uint32_t can hold, which is what the host's own Network
 * holds for it, read out of the host's Network.framework with a program that prints the value of
 * the symbol.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>

const uint32_t _nw_data_transfer_report_all_paths = UINT32_MAX;
