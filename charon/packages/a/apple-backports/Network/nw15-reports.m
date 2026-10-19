#import "CharonNW.h"

nw_interface_radio_type_t nw_data_transfer_report_get_path_radio_type(nw_data_transfer_report_t report, uint32_t path_index)
{
    CharonNWDataTransferReport *value = (CharonNWDataTransferReport *)report;
    if (!value || value->_state != nw_data_transfer_report_state_collected)
        return nw_interface_radio_type_unknown;
    if (path_index != 0 && path_index != _nw_data_transfer_report_all_paths)
        return nw_interface_radio_type_unknown;
    return value->_radioType;
}
