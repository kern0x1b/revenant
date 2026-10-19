#import "RevenantNW.h"

extern void RevenantNWBrowserSetQueue(nw_browser_t, dispatch_queue_t);
extern void RevenantNWBrowserSetStateHandler(nw_browser_t, nw_browser_state_changed_handler_t);
extern void RevenantNWBrowserSetResultsHandler(nw_browser_t, nw_browser_browse_results_changed_handler_t);
extern nw_browse_descriptor_t RevenantNWBrowserCopyBrowseDescriptor(nw_browser_t);
extern nw_parameters_t RevenantNWBrowserCopyParameters(nw_browser_t);
extern void RevenantNWBrowserStart(nw_browser_t);

void nw_browser_set_queue(nw_browser_t browser, dispatch_queue_t queue)
{
    RevenantNWBrowserSetQueue(browser, queue);
}

void nw_browser_set_state_changed_handler(nw_browser_t browser, nw_browser_state_changed_handler_t handler)
{
    RevenantNWBrowserSetStateHandler(browser, handler);
}

void nw_browser_set_browse_results_changed_handler(nw_browser_t browser, nw_browser_browse_results_changed_handler_t handler)
{
    RevenantNWBrowserSetResultsHandler(browser, handler);
}

nw_browse_descriptor_t nw_browser_copy_browse_descriptor(nw_browser_t browser)
{
    return RevenantNWBrowserCopyBrowseDescriptor(browser);
}

nw_parameters_t nw_browser_copy_parameters(nw_browser_t browser)
{
    return RevenantNWBrowserCopyParameters(browser);
}

void nw_browser_start(nw_browser_t browser)
{
    RevenantNWBrowserStart(browser);
}

nw_endpoint_t nw_browse_result_copy_endpoint(nw_browse_result_t result)
{
    RevenantNWBrowseResult *value = (RevenantNWBrowseResult *)result;
    return value ? (nw_endpoint_t)value->_endpoint : NULL;
}

nw_txt_record_t nw_browse_result_copy_txt_record_object(nw_browse_result_t result)
{
    RevenantNWBrowseResult *value = (RevenantNWBrowseResult *)result;
    return value ? (nw_txt_record_t)value->_txtRecord : NULL;
}

size_t nw_browse_result_get_interfaces_count(nw_browse_result_t result)
{
    RevenantNWBrowseResult *value = (RevenantNWBrowseResult *)result;
    return value ? value->_interfaces.count : 0;
}

void nw_browse_result_enumerate_interfaces(nw_browse_result_t result, NW_NOESCAPE nw_browse_result_enumerate_interface_t enumerator)
{
    RevenantNWBrowseResult *value = (RevenantNWBrowseResult *)result;
    if (!value || !enumerator)
        return;
    for (id interface in [value->_interfaces copy]) {
        if (!enumerator((nw_interface_t)interface))
            break;
    }
}

nw_browse_result_change_t nw_browse_result_get_changes(nw_browse_result_t old_result, nw_browse_result_t new_result)
{
    RevenantNWBrowseResult *before = (RevenantNWBrowseResult *)old_result;
    RevenantNWBrowseResult *after = (RevenantNWBrowseResult *)new_result;
    if (!before && !after)
        return nw_browse_result_change_invalid;
    if (!before)
        return nw_browse_result_change_result_added;
    if (!after)
        return nw_browse_result_change_result_removed;
    nw_browse_result_change_t changes = 0;
    for (nw_interface_t interface in before->_interfaces) {
        if (![after->_interfaces containsObject:(id)interface])
            changes |= nw_browse_result_change_interface_removed;
    }
    for (nw_interface_t interface in after->_interfaces) {
        if (![before->_interfaces containsObject:(id)interface])
            changes |= nw_browse_result_change_interface_added;
    }
    if (!nw_txt_record_is_equal((nw_txt_record_t)before->_txtRecord, (nw_txt_record_t)after->_txtRecord))
        changes |= nw_browse_result_change_txt_record_changed;
    return changes ? changes : nw_browse_result_change_identical;
}
