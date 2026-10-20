# WebSocket, the options, the metadata and the handshake

`nw_ws_create_options`, its setters, `nw_ws_create_metadata` and its accessors, and the request and
response objects of the handshake are the configuration and the description of a WebSocket connection.
The port has no WebSocket transport, so a connection of WebSocket options carries no WebSocket layer;
what is here is what a program sets and reads back, which is real and is what the host's own Network
answers for the same calls.

A message created with `nw_ws_create_metadata` answers the opcode it was made with and a close code of
1005, `nw_ws_close_code_no_status_received` - the code for a message that carries no status of its own -
and takes whatever close code a program sets. A response keeps the status and the subprotocol it was
made with and enumerates the headers that were added to it, and a metadata answers the server's
response only once one has been set on it.
