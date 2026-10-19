# DESFILE — file encryption with the MC6859

Encrypts or decrypts a FLEX text file using the board's MC6859 Data
Security Device, a hardware DES chip. There are two versions that do the
same job and read and write the same file format:

| File | What it is |
|---|---|
| `DESFILE.BAS` | TSC Extended BASIC version: slow, but shows every step of driving the chip |
| `DESFILE.asm` / `DESFILE.CMD` | Native FLEX command, about 100 times faster |

Files encrypted by one can be decrypted by the other. This has been checked
on the board in both directions.

**The MC6859 is rated at 1 MHz.** Run these on a board with a 1 MHz bus and
the 2XE clock at twice the bus clock. On a 2 MHz board the chip reports
parity errors.

## Using it

```
+++DESFILE
ENCRYPT OR DECRYPT (E/D)? E
INPUT FILE? NOTES.TXT
OUTPUT FILE? NOTES.ENC
KEY (UP TO 8 CHARS): secret
DONE
```

For the BASIC version, `RUN` DESFILE.BAS under XBASIC and answer the same
prompts. The command version defaults file names to `.TXT` (BASIC defaults
to `.DAT`), so give the extension when it is anything else. The output file
must not already exist. To rebuild the command:

```
a09 -FDESFILE.CMD DESFILE.asm
```

## File format and key

- **DES in ECB mode**, 8-byte blocks. The text is encrypted byte for byte,
  including its CRs, and the last block is padded with `$00` bytes, which
  decryption drops.
- **Ciphertext is written as hex text**, upper case, 64 hex digits per line.
  Raw ciphertext can contain `$00` and `$0D`, which FLEX text files don't
  survive. Hex doubles the size, so an encrypted file is about twice as big
  as the original. Decryption ignores spaces, line breaks and letter case in
  the hex.
- **The key** is up to 8 characters, padded with spaces, and case matters.
  Each character's 7 bits go into D7–D1 of a key byte and D0 is set to give
  odd parity, which the chip checks.

ECB encrypts identical 8-byte blocks to identical ciphertext. This is a
demonstration of the chip, not strong protection for real secrets.

## MC6859 registers

| Address | Write | Read |
|---|---|---|
| `$F278` | Data bytes 1–7 | — |
| `$F279` | Reset | — |
| `$F27A` | Enter major key (8 bytes) | Status: D7 parity error, D6 busy |
| `$F27C` | Byte 8, then decipher | Result data (8 reads) |
| `$F27D` | Byte 8, then encipher | — |

The chip's chip-select inputs are wired to A3–A5, so it responds only in
the top 8 bytes of its `$F240`–`$F27F` decode window. The assembler version
uses only plain loads and stores on these registers: instructions such as
`CLR` and `INC` read before they write, and a read can have side effects.

## Speed

Encrypting the 3.4 KB `DESFILE.BAS` listing takes a couple of minutes in
BASIC, where most of the time goes on building the hex strings. The command
version needs about one second of processor time at 1 MHz, plus the disk
access.
