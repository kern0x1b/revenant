import Dispatch
import Foundation
import Network

@available(macOS 10.14, iOS 12.0, *)
func openShapes(queue: DispatchQueue, host: String, port: UInt16, serverName: String?, alpn: [String]) {
    let configureTcp: nw_parameters_configure_protocol_block_t = { options in
        nw_tcp_options_set_no_delay(options, true)
        nw_tcp_options_set_connection_timeout(options, 15)
    }
    let parameters: nw_parameters_t
    if let serverName = serverName {
        parameters = nw_parameters_create_secure_tcp({ options in
            let security = nw_tls_copy_sec_protocol_options(options)
            sec_protocol_options_set_tls_server_name(security, serverName)
            sec_protocol_options_set_tls_false_start_enabled(security, true)
            for name in alpn {
                sec_protocol_options_add_tls_application_protocol(security, name)
            }
            sec_protocol_options_set_verify_block(security, { _, _, complete in
                complete(true)
            }, queue)
        }, configureTcp)
    } else {
        parameters = nw_parameters_create()
        let tcp = nw_tcp_create_options()
        configureTcp(tcp)
        nw_protocol_stack_set_transport_protocol(nw_parameters_copy_default_protocol_stack(parameters), tcp)
    }
    let endpoint = nw_endpoint_create_host(host, "\(port)")
    let connection = nw_connection_create(endpoint, parameters)
    nw_connection_set_queue(connection, queue)
    nw_connection_set_state_changed_handler(connection) { state, error in
        switch state {
        case nw_connection_state_waiting, nw_connection_state_failed:
            if let error = error {
                _ = nw_error_get_error_domain(error).rawValue
                _ = nw_error_get_error_code(error)
                _ = CFErrorCopyDescription(nw_error_copy_cf_error(error).takeRetainedValue())
            }
        case nw_connection_state_ready:
            break
        default:
            break
        }
    }
    nw_connection_start(connection)
    let content = Data([1]).withUnsafeBytes { DispatchData(bytes: $0) }
    nw_connection_send(connection, content as __DispatchData, _nw_content_context_default_message, true) { error in
        _ = error
    }
    nw_connection_receive(connection, 1, 256 * 1024) { content, _, isComplete, error in
        _ = content
        _ = isComplete
        _ = error
    }
    nw_connection_cancel(connection)
}

print("cseam shapes compiled")
