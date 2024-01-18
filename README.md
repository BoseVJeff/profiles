# Portable Powershell (PPS)

This is my profile for the purposes of having a portable developer setup.

Current specs that are external and not documented using this config:

* Hardware: 256 GB Sandisk, formatted as exFAT.

    This is formatted as exFAT only for comaptiblity reasons. If you don't care about this (if so, do you *really* care about having a truly portable setup?), feel free to format it as NTFS or APFS or something else that makes sense to you. This will give you the freedom to use symlinks, making a lot of the setup easier should you desire to recreate it.

    The formatting tool of choice here is [Ventoy](https://github.com/ventoy/Ventoy). This lets me use this drive as a bootable medium to boot various ISOs from, while also leaving me with the freedom to use this as a storage drive.

## Motivation

The major motivation here is to have a development setup that I can carry accross machines. Why - because I'm too lazy to lug my laptop all around (but not lazy enough to not write this entire thing up!).

## Notes

Out of the box, anything that requires an API key will not work. To make that work, refer to `ps_modules\tokens\tokens_dummy.txt`.