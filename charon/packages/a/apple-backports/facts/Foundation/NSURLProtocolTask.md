# A protocol that serves a session's task, iOS 8.0

Source: the SDK 26.2 headers, which declare all three as the task-shaped spelling of something older.

`+canInitWithTask:` is `+canInitWithRequest:` with the task's current request (its `originalRequest`
when it has no current one), and nil for a task with neither. `-initWithTask:cachedResponse:client:`
is `-initWithRequest:cachedResponse:client:` with that request, and the task is kept beside the
protocol so that the code a protocol runs can ask which task it is serving -- which is what the
`task` property is for. A protocol subclass that serves a session reads the task from there and nothing
else changes.
