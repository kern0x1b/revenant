# MLCDevice, on a machine with no GPU and no Neural Engine

Measured on the host, and measured on what iOS 6.1.3 has. The host has a Metal device and an Apple
Neural Engine; this release has neither: no Metal framework and no Neural Engine at all. So the
device classes are carried whole and each side answers as a machine with the hardware it has.

| Call | Host (macOS, a Metal device and an ANE) | Port (iOS 6.1.3) |
| --- | --- | --- |
| `+[MLCDevice cpuDevice]` | `type` 0, `actualDeviceType` 0, `gpuDevices` empty | the same |
| `+[MLCDevice gpuDevice]` | a device, `type` 1, `actualDeviceType` 1, one Metal device | nil |
| `+[MLCDevice aneDevice]` | a device, `type` 3, `actualDeviceType` 3 | nil |
| `+[MLCDevice deviceWithType:MLCDeviceTypeGPU]` | a device, `type` 1 | nil |
| `+[MLCDevice deviceWithType:MLCDeviceTypeCPU]` | a device, `type` 0 | the same |
| `+[MLCDevice deviceWithType:MLCDeviceTypeAny]` | a device, `type` **0** | the same |
| `+[MLCDevice deviceWithType:MLCDeviceTypeAny selectsMultipleComputeDevices:YES]` | a device, `type` 0 | the same |
| `+[MLCDevice deviceWithGPUDevices:]` | a device | nil |
| `gpuDevices` | one Metal device | empty |
| `-copyWithZone:` | a device of the same type | the same |

`MLCDeviceTypeAny` is a request rather than a device: the framework answers with the device that
will do the work, and on a machine with a CPU, a GPU and an Neural Engine it chose the CPU here
(`type` 0, not 2), so the port resolves it to the CPU as well and reports that. A request for a
device this release does not have is refused the way a machine without that device refuses it: nil
rather than an object that would fail later.

The `gpuDevices` list is empty, not nil, and a list of Metal devices cannot be asked for at all:
`+deviceWithGPUDevices:` answers nil whatever it is given, because every element of such a list
names a device this release has none of.

Nothing here is a silent empty: a program that asks for a GPU and is answered nil has been told
there is none, which is the answer a machine with no GPU gives, and the framework's own answer on
such a machine.
