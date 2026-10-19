/*
 * The browser calls of Network that arrived after the ones nw12-browser.m carries, and which the 16.0
 * cache is the first to export, so an object of their own: the ladder this port builds has no rung
 * between 12.0 and 16.0, and a symbol is placed at the first rung that exports it. The SDK's header
 * gives this family iOS 13, which is a rung the ladder does not hold. `tools/release-split.lua` is the
 * same measurement, and it is what splits this library's objects.
 *
 * The object itself is in nw12-browser.m, and every call here is the seam that file exposes for it: a
 * setter, a copy and the start reach it through the C functions at the end of that file, and the
 * browse result's own calls read the result's ivars, which `CharonNW.h` declares once for the library.
 *
 * What each call answers is in `facts/Network/NWBrowser.md`: a browse is the release's own
 * `DNSServiceBrowse` and the record of each instance its `DNSServiceResolve`, a result is reported once
 * that resolve has answered, and the interfaces of a result are the objects the library's path monitor
 * makes, keyed by the interface index every DNS-SD answer carries.
 */

#import "CharonNW.h"

/* What the object's own file exposes, for the reason its comment gives: the class is declared there and
   a class's ivar offsets are emitted by every file that sees its @interface, so this file does not see
   it and asks for what it needs. */
extern void CharonNWBrowserSetQueue(nw_browser_t, dispatch_queue_t);
extern void CharonNWBrowserSetStateHandler(nw_browser_t, nw_browser_state_changed_handler_t);
extern void CharonNWBrowserSetResultsHandler(nw_browser_t, nw_browser_browse_results_changed_handler_t);
extern nw_browse_descriptor_t CharonNWBrowserCopyBrowseDescriptor(nw_browser_t);
extern nw_parameters_t CharonNWBrowserCopyParameters(nw_browser_t);
extern void CharonNWBrowserStart(nw_browser_t);

void nw_browser_set_queue(nw_browser_t browser, dispatch_queue_t queue)
{
    CharonNWBrowserSetQueue(browser, queue);
}

void nw_browser_set_state_changed_handler(nw_browser_t browser, nw_browser_state_changed_handler_t handler)
{
    CharonNWBrowserSetStateHandler(browser, handler);
}

void nw_browser_set_browse_results_changed_handler(nw_browser_t browser, nw_browser_browse_results_changed_handler_t handler)
{
    CharonNWBrowserSetResultsHandler(browser, handler);
}

nw_browse_descriptor_t nw_browser_copy_browse_descriptor(nw_browser_t browser)
{
    return CharonNWBrowserCopyBrowseDescriptor(browser);
}

nw_parameters_t nw_browser_copy_parameters(nw_browser_t browser)
{
    return CharonNWBrowserCopyParameters(browser);
}

void nw_browser_start(nw_browser_t browser)
{
    CharonNWBrowserStart(browser);
}

/* What a browse result says about one service: the endpoint a program connects to, the record the
   service advertised when the descriptor asked for one, and the interfaces it was found on. A result
   is built by the browser once the service has resolved, and its endpoint names the service - instance,
   type and domain - and carries no port, which is what Apple's own browse result answers. */
nw_endpoint_t nw_browse_result_copy_endpoint(nw_browse_result_t result)
{
    CharonNWBrowseResult *value = (CharonNWBrowseResult *)result;
    return value ? (nw_endpoint_t)value->_endpoint : NULL;
}

nw_txt_record_t nw_browse_result_copy_txt_record_object(nw_browse_result_t result)
{
    CharonNWBrowseResult *value = (CharonNWBrowseResult *)result;
    return value ? (nw_txt_record_t)value->_txtRecord : NULL;
}

size_t nw_browse_result_get_interfaces_count(nw_browse_result_t result)
{
    CharonNWBrowseResult *value = (CharonNWBrowseResult *)result;
    return value ? value->_interfaces.count : 0;
}

void nw_browse_result_enumerate_interfaces(nw_browse_result_t result, NW_NOESCAPE nw_browse_result_enumerate_interface_t enumerator)
{
    CharonNWBrowseResult *value = (CharonNWBrowseResult *)result;
    if (!value || !enumerator)
        return;
    for (id interface in [value->_interfaces copy]) {
        if (!enumerator((nw_interface_t)interface))
            break;
    }
}

/* The changes between two results, as the bits the header names: an interface that became available,
   an interface that went away, a record that changed. `identical` is what two results differing in
   nothing answer, and a result added and a result removed are what one end of a pair being empty
   answers. */
nw_browse_result_change_t nw_browse_result_get_changes(nw_browse_result_t old_result, nw_browse_result_t new_result)
{
    CharonNWBrowseResult *before = (CharonNWBrowseResult *)old_result;
    CharonNWBrowseResult *after = (CharonNWBrowseResult *)new_result;
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