# MPSTemporaryImage: the read count and the reclaim at zero, measured on the macOS 26 host

`+[MPSTemporaryImage temporaryImageWithCommandBuffer:imageDescriptor:]` (MPSImage.h:938) makes an image whose storage is
reclaimed after its last read. Measured with `MPSImageGaussianBlur` as the reader:

* A fresh temporary image has `readCount` 1, and a texture.
* `setReadCount:2` stores 2.
* Each encode that reads the image decrements `readCount` by one.
* The read that takes `readCount` to 0 reclaims the storage: the texture pointer changes on the next access.
* An encode that reads the image after that is refused by an assertion with the text
  `source image is a temporary image with readCount of 0.` and `Backing texture for source image is no longer valid.`
  The process aborts.

The port's `MPSTemporaryImage` decrements the count (`CharonMPSConsumeReadCount`, CharonMPS.h) and never reclaims, so
a read after zero is accepted. That is not what Apple does, and the port does not implement the reclaim. It needs the
kernel name in the refusal text, which the port's shared helper does not have, and the port's textures run on the
device only, so the reclaim cannot be checked on the host from the port's side.

Probe: `.agent-work/runs/mps-metal/probe/gaussian/temp.m` (not in the tree).
