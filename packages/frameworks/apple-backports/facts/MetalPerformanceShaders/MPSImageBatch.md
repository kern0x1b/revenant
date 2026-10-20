# MPSImageBatchIncrementReadCount() and MPSImageBatchSynchronize() (11.3)

The two batch helpers of MPSImage.h (112-141), in `MetalPerformanceShaders/MPSImageBatch11.m`.

## What Metal does, measured on the macOS 26 host

* **IncrementReadCount** adds `amount` to the read count of each distinct image in the batch, once per image however
  often it is listed, and returns how many distinct images it counted. A batch `[a, a, b]` of temporary images with
  `+2` counts 2 and leaves `a` and `b` at 3 each (both were at 1).
* Only a temporary image has a read count, so **a plain image is not counted**: a batch of plain images returns 0, and a
  mixed batch `[plain, temp]` returns 1.
* A negative amount lowers the count.
* **Synchronize** calls `synchronizeResource:` on each resource. On a plain image it returns and the command buffer
  completes (status 4).
* On a **temporary image** it stops the process with an assertion, and the text names the index of the first temporary
  image: `MPSImageBatchSynchronize(): Error: image[1] is a temporary image and can not be read on the CPU.` (status 134).

## What the port does

* IncrementReadCount counts and moves the read counts as Metal does (`tests/backports/host/mps-image-batch`).
* Synchronize does nothing for a plain image, because the port's resources are CPU-resident, so there is nothing to
  synchronise: the port's answer and Metal's coincide in effect. It raises the same text as an
  `NSInternalInconsistencyException` for a temporary image, which an uncaught process ends with status 134 as Metal does.

## Not measured

* A batch that mixes images of different formats. Apple's documentation says the images should share their descriptor
  parameters, and no mixed batch was measured.
* The synchronise on a plain image that is not CPU-resident: the port has no such image.
