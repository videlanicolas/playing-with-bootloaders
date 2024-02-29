# Playing with Bootloaders

It's been a while since I've coded in assembler, so I figured I'd play with bootloaders to brush up my assembler knowledge and also do something fun along the way.

## Helloworld

Simple bootloader to get things started.

```bash
$ ./run.sh helloworld
```

```
Booting from Hard Disk...
Boot failed: could not read the boot disk

Booting from Floppy...
Hello World!
```

## Print HEX

Now the bootloader prints HEX numbers, fancy!

```bash
$ ./run.sh print_hex_addresses
```

```
Booting from Hard Disk...
Boot failed: could not read the boot disk

Booting from Floppy...
0x1fa5
```