#!/usr/bin/env python3
"""Tiny M*PS assembler for the TetrIC processor.

Python port of abnasm.pl, (C) Anders Berkeman 2002, with additions by the
TetrIC team. Usage:

    abnasm.py prg.s        ->  prg.1 (listing), prg.2 (hex), prg.bin (binary)

The assembler is a simple two-pass design, implemented in three passes:
  1. Macro expansion, syntax checking and label collecting -> .1 file
  2. Hex code generation from known labels and the .1 file -> .2 file
  3. Generation of the binary (big endian 32-bit words)    -> .bin file

The output is intended to be identical to the Perl version, including the
quirks (see the comments marked "Perl:"). Differences: an unknown register
name is an error (Perl silently used register 0), $R0/$r0 is accepted,
macros can use other macros (Perl silently dropped the rest of the outer
macro), and negative .dc/.pad values are stored correctly (a 64-bit Perl
stored them as -1).

After assembly the code is checked for pipeline hazards (missing nops, see
rtl/processor/PIPELINE_HAZARDS.md). Violations are errors and no .bin is
written; use --hazards=warn or --hazards=off to relax this.
--suggest-nops lists nops that can be removed without breaking the rules,
--remove-nops OUT.s also writes a copy of the source without them.

Syntax summary
  label:  MNEMONIC args        ; comment     (# also starts a comment)
  Labels start in column 0, instructions are indented.
  Registers: $0..$31, $zero, $at, $v0, $t0, ... (see REGS)
  Numbers: 123, -5, 0x1f, 0b101, 017 (octal), 'a'
  Immediates may be labels or expressions with + - * / ^ ~ | & and [ ].
  label.L / label.H selects the low / high 16 bits.
  Directives: .ORG .DC .PAD .FILE (name [words], default whole file) .ASCII .EQU (=) .END .MACRO/.ENDMACRO
              .TRANSTAB .TR .TRANSLATE .TRANSOFF
"""

import argparse
import os
import re
import sys

# simple mapping from register name to register number
REGS = {
    "ZERO": 0, "AT": 1, "V0": 2, "V1": 3, "A0": 4, "A1": 5, "A2": 6, "A3": 7,
    "T0": 8, "T1": 9, "T2": 10, "T3": 11, "T4": 12, "T5": 13, "T6": 14, "T7": 15,
    "S0": 16, "S1": 17, "S2": 18, "S3": 19, "S4": 20, "S5": 21, "S6": 22, "S7": 23,
    "T8": 24, "T9": 25, "K0": 26, "K1": 27, "GP": 28, "SP": 29, "FP": 30, "RA": 31,
    "S8": 30,
    # Some TetrIC-specific aliases
    "SFX": 26, "GFX": 27, "LUT": 28, "SCR": 30,
    "R0": 0, "R1": 1, "R2": 2, "R3": 3, "R4": 4, "R5": 5, "R6": 6, "R7": 7,
    "R8": 8, "R9": 9, "R10": 10, "R11": 11, "R12": 12, "R13": 13, "R14": 14, "R15": 15,
    "R16": 16, "R17": 17, "R18": 18, "R19": 19, "R20": 20, "R21": 21, "R22": 22, "R23": 23,
    "R24": 24, "R25": 25, "R26": 26, "R27": 27, "R28": 28, "R29": 29, "R30": 30, "R31": 31,
}

# First four chars: expected arguments, read left to right, space terminates.
#   S,T,D register   H 5 bit shift amount (<< 6)   I 16 bit immediate
#   B 16 bit branch immediate (pc relative if label)   J 26 bit immediate
# Rest: instruction code in hex.
INSTRS = {
    "ADD": "DST 00000020", "ADDU": "DST 00000021",
    "ADDI": "TSI 20000000", "ADDIU": "TSI 24000000",
    "AND": "DST 00000024", "ANDI": "TSI 30000000",
    "NOR": "DST 00000027", "OR": "DST 00000025",
    "ORI": "TSI 34000000", "SLLV": "DTS 00000004",
    "SRAV": "DTS 00000007", "SRLV": "DTS 00000006",
    "SUB": "DST 00000022", "SUBU": "DST 00000023",
    "XOR": "DST 00000026", "XORI": "TSI 38000000",
    "LUI": "TI  3C000000", "SLT": "DST 0000002A",
    "SLTU": "DST 0000002B", "SLTI": "TSI 28000000",
    "SLTIU": "TSI 2C000000", "BEQ": "STB 10000000",
    "BGE": "STB 04000000", "BGT": "STB 1C000000",
    "BNE": "STB 14000000", "J": "J   08000000",
    "JAL": "J   0C000000", "JALR": "SD  00000009",
    "JR": "S   00000008", "LW": "TIS 8C000000",
    "SW": "TIS AC000000",
    # tetric project specific
    "SLL": "DSH 00000000",  # should be DTH in real MIPS!
    "SRA": "DSH 00000003",  # should be DTH in real MIPS!
    "SRL": "DSH 00000002",  # should be DTH in real MIPS!
    "MFC0": "D   40000000", "MFC1": "DT  44000000",
    "MFC2": "D   48000000", "MFC3": "D   4C000000",
    # aliases
    "CLR": "D   00000025",   # based on or
    "NOP": "    00000000",
    "MOV": "DT  00000025",   # based on or
    "MOVI": "TI  20000000",  # based on addi -> sign extend
    "MOVIU": "TI  34000000", # based on ori, no sign extend
    "NOT": "DT  00000027",   # based on nor (rd:= $0 nor rt)
    "NEG": "DT  00000022",   # based on sub (rd:= $0-rt)
    "BEQZ": "SB  10000000",  # based on Bxx with rt=$0
    "BGEZ": "SB  04000000",
    "BGTZ": "SB  1C000000",
    "BNEZ": "SB  14000000",
    "B": "B   10000000",     # unconditional branch (beq $0,$0,offset)
}

DIRECTIVES = {".DC", ".ORG", ".END", ".MACRO", ".FILE", ".PAD", ".ENDMACRO",
              "=", ".EQU", ".TRANSTAB", ".TRANSLATE", ".TRANSOFF", ".TR", ".ASCII"}

# bit position of the S, T and D register fields
STD_SHIFT = {"S": 21, "T": 16, "D": 11}

MASK64 = (1 << 64) - 1


class AsmError(Exception):
    pass


# ---------------------------------------------------------------- helpers
def perl_split(pattern, s):
    """split(/pattern/, s) with Perl semantics (trailing empty fields removed)."""
    fields = re.split(pattern, s)
    while fields and fields[-1] == "":
        fields.pop()
    return fields


def perl_num(v):
    """Numeric value of a Perl scalar (leading decimal number, else 0)."""
    if isinstance(v, int):
        return v
    m = re.match(r"\s*([-+]?\d+)", v)
    return int(m.group(1)) if m else 0


def perl_oct(s):
    """Perl oct(): 0x.. hex, 0b.. binary, otherwise octal (stops at bad digit)."""
    s = s.strip()
    low = s.lower()
    if low.startswith("0x") or low.startswith("x"):
        m = re.match(r"[0-9a-fA-F_]*", s[low.index("x") + 1:])
        return int(m.group(0).replace("_", "") or "0", 16)
    if low.startswith("0b") or low.startswith("b"):
        m = re.match(r"[01_]*", s[low.index("b") + 1:])
        return int(m.group(0).replace("_", "") or "0", 2)
    m = re.match(r"[0-7_]*", s)
    return int(m.group(0).replace("_", "") or "0", 8)


def todec(v):
    """Perl todec(): octal/hex/bin if it starts with 0, char if it starts
    with ', otherwise the value is returned unchanged (string or int)."""
    if isinstance(v, int):
        return v
    if v.startswith("0"):
        return perl_oct(v)
    if v.startswith("'"):
        return ord(v[1]) if len(v) > 1 else 0
    return v


def isnum(v):
    s = re.sub(r"\.[LH]$", "", str(v))
    return bool(re.match(r"^0[0-7]*$", s) or          # octal or zero
                re.match(r"^[-]?[1-9][0-9]*$", s) or  # decimal, may be negative
                re.match(r"^0x[A-Fa-f0-9]+$", s) or   # hex
                re.match(r"^0b[0-1]+$", s) or         # bin
                s.startswith("'"))                    # ASCII


def _hex(v, width):
    # 32-bit two's complement. Perl: on a 64-bit Perl, %x of a negative
    # number has 16 digits and pack("H8") then keeps "ffffffff", so every
    # negative .dc/.pad value became -1. The original 32-bit Perl did this.
    v = perl_num(v) & 0xffffffff
    return "%x" % v if len("%x" % v) >= width else ("%x" % v).rjust(width, "0")


def hex8(v):
    return "0x" + _hex(v, 8)


def hex4(v):
    return "0x" + _hex(v, 4)[-4:]


def hex2(v):
    return "0x" + _hex(v, 2)[-2:]


def hex2no0x(v):
    return _hex(v, 2)[-2:]


def prettyp(s, n):
    s = str(s)
    return s + " " * (n - len(s)) if n > len(s) else s + " "


# ---------------------------------------------------------------- assembler
class Assembler:
    def __init__(self, name):
        self.namei = name
        # Perl: s/\..+/.1/ on the file name (applied to the base name here)
        m = re.match(r"(.*/)?([^/]*)$", name)
        base_dir, base = m.group(1) or "", m.group(2)
        self.name1 = base_dir + re.sub(r"\..+", ".1", base, count=1)
        self.name2 = base_dir + re.sub(r"\..+", ".2", base, count=1)
        self.name3 = base_dir + re.sub(r"\..+", ".bin", base, count=1)
        if self.name1 == name:
            self.name1, self.name2, self.name3 = name + ".1", name + ".2", name + ".bin"
        self.labels = {}
        self.code = []      # assembled instructions: (pc, word, lineno, mnemonic, args)
        self.macros = {}
        self.trans = {}

    def die(self, lineno, msg):
        raise AsmError("%s:%s: %s at line %s" % (self.namei, lineno, msg, lineno))

    def warn(self, lineno, msg):
        sys.stderr.write("%s:%s: # %s at line %s\n" % (self.namei, lineno, msg, lineno))

    # ---- expression evaluation
    def evaluate(self, data, lineno):
        data = data.replace("[", "(").replace("]", ")")
        temp = re.sub(r"[()+\-*/^~|&]", " ", data)
        for label in temp.split(" "):
            if label == "" or isnum(label):
                continue
            if label.upper() in self.labels:
                # Perl: s/$label/value/g (label used as a regex)
                value = str(self.labels[label.upper()])
                data = re.sub(label, lambda _m: value, data)
            else:
                self.die(lineno, 'Label "%s" not defined' % label)
        expr = data.lower()
        # Perl number literals: 0x.., 0b.., 0... is octal
        expr = re.sub(r"\b0x[0-9a-f]+\b|\b0b[01]+\b|\b0[0-7]+\b|\b\d+\b",
                      lambda m: str(perl_oct(m.group(0)) if m.group(0).startswith("0")
                                    else int(m.group(0))), expr)
        try:
            return int(eval(expr, {"__builtins__": {}}, {}))
        except Exception:
            return 0   # Perl: a failing eval gives undef -> 0

    def getvalue(self, val, lineno):
        val = str(val)
        lohi = "H" if val.endswith(".H") else "L" if val.endswith(".L") else "0"
        val = re.sub(r"\.[LH]$", "", val)
        if not isnum(val):
            val = self.evaluate(val, lineno)
        val = perl_num(todec(val))
        if lohi == "L":
            val &= 0xffff
        elif lohi == "H":
            val = (val >> 16) & 0xffff
        return val

    # ---- pass 1: parse and macro expand -> list file
    def pass1(self, src_lines):
        out = []
        it = iter(src_lines)
        macroname = ""
        eat = False      # defining a macro
        # macro expansions in progress: [remaining lines, argument translation].
        # Perl: a macro used inside a macro replaced the outer expansion, so the
        # rest of the outer macro was silently lost. Here they nest properly.
        mstack = []
        transtab = False
        translate = False
        lineno = 0
        pc = 0

        def write(label, command, args):
            out.append(prettyp(lineno, 6) + prettyp(label, 16) +
                       prettyp(command, 8) + prettyp(args, 16) + "\n")

        while True:
            label, command, args = "", "", ""
            while mstack and not mstack[-1][0]:
                mstack.pop()
            if mstack:
                raw = mstack[-1][0].pop(0)
                cur_trans = mstack[-1][1]
            else:
                cur_trans = None
                raw = next(it, None)
                if raw is None:
                    break
                lineno += 1

            # remove comments
            raw = re.sub(r"#.*", "", raw)
            raw = re.sub(r";.*", "", raw)

            if cur_trans is not None:
                for arg, val in cur_trans.items():
                    raw = re.sub(arg, lambda _m, v=val: "" if v is None else v, raw)
            if translate:
                for arg, val in self.trans.items():
                    raw = re.sub(arg, lambda _m, v=val: v, raw)

            spt = perl_split(r"[\s,()]+", raw)
            if re.match(r"^\s*$", raw):
                continue

            label = (spt.pop(0) if spt else "").upper()
            label = re.sub(r":$", "", label)
            if label in self.labels:
                self.die(lineno, "Label redefined")
            label_done = False
            line_pc = pc

            command = (spt.pop(0) if spt else "").upper()

            if command in ("LW", "SW"):
                my = list(spt)
                arga = (my.pop(0) if my else "").upper()
                argb = (my.pop(0) if my else "").upper()
                argc = (my.pop(0) if my else "").upper()
                tb, tc = argb[1:], argc[1:]
                if command == "LW":
                    # Perl: leftover debug prints end up in the list file
                    out.append("%s\n" % tc)
                    out.append("$%s\n" % tc)
                if tb in REGS:
                    spt = [arga, "0", argb]
                elif tc not in REGS and not isnum(tc):
                    spt = [arga, argb, "$zero"]

            if command == "":
                pass
            elif command in DIRECTIVES:
                if command == ".MACRO":
                    if eat:
                        self.die(lineno, "Macro in macro")
                    eat = True
                    macroname = (spt.pop(0) if spt else "").upper()
                    self.macros.setdefault(macroname, []).append(" ".join(spt) + "\n")
                    continue
                if command == ".ENDMACRO":
                    if not eat:
                        self.die(lineno, "Not defining macro")
                    eat = False
                    macroname = ""
                    continue
                if not eat:
                    if command == ".TRANSTAB":
                        if transtab or translate:
                            self.die(lineno, "Already in translate phase")
                        self.trans = {}
                        transtab, translate = True, False
                        continue
                    if command == ".TRANSLATE":
                        if not transtab:
                            self.die(lineno, "Should get to TRANSLATE from TRANSTAB")
                        transtab, translate = False, True
                        args = "; __TR " + "".join("[%s->%s] " % kv for kv in self.trans.items())
                        write(label, "", args)
                        continue
                    if command == ".TRANSOFF":
                        if not (transtab or translate):
                            self.die(lineno, "Not translating")
                        transtab = translate = False
                        continue
                    if command == ".TR":
                        if not transtab:
                            self.die(lineno, "Not translating")
                        self.trans[spt[0]] = spt[1]
                        continue
                    if command in (".EQU", "="):
                        value = spt.pop(0) if spt else ""
                        if label == "" or value == "":
                            self.die(lineno, "Bogus assignment")
                        self.labels[label] = self.getvalue(value, lineno)
                        continue
                    if command == ".END":
                        break
                    if command == ".DC":
                        if label != "":
                            self.labels[label] = pc
                            label_done = True
                        for i, data in enumerate(spt):
                            if i % 4 == 3:
                                write(label, command, args)
                                args, label = "", ""
                            args += " " + data
                            pc += 1
                    elif command == ".ASCII":
                        if label != "":
                            self.labels[label] = pc
                            label_done = True
                        right = raw.rfind('"')
                        left = raw.rfind('"', 0, right)
                        string = raw[left:right + 1]
                        write(label, command, string)
                        pc += (len(string) - 2) // 4 + 1
                        continue
                    elif command == ".ORG":
                        pc = self.getvalue(spt.pop(0) if spt else "", lineno)
                        args = " " + hex8(pc)
                        if label != "":
                            self.labels[label] = pc
                            label_done = True
                    elif command == ".PAD":
                        if len(spt) < 2:
                            self.die(lineno, "Missing args")
                        length, value = spt[0], spt[1]
                        args += " %s %s" % (length, value)
                        pc += self.getvalue(length, lineno)
                    elif command == ".FILE":
                        if len(spt) < 1:
                            self.die(lineno, "Missing args")
                        fname = spt[0].replace('"', "")
                        if len(spt) >= 2:
                            length = spt[1]
                        else:
                            # no length: the whole file, rounded up to words
                            try:
                                length = str((os.path.getsize(fname) + 3) // 4)
                            except OSError:
                                self.die(lineno, "Could not find incbin file %s" % fname)
                        args += " %s %s" % (fname, length)
                        pc += self.getvalue(length, lineno)
            elif command in self.macros:
                if not eat:
                    if len(mstack) >= 32:
                        self.die(lineno, "Macros nested too deep (recursive macro?)")
                    macrotext = list(self.macros[command])
                    template = perl_split(r"\s", macrotext.pop(0).rstrip("\n"))
                    transarg = {}
                    mstack.append([macrotext, transarg])
                    for i, arg in enumerate(template):
                        transarg[arg] = spt[i] if i < len(spt) else None
                    args = "; %s " % command + "".join(
                        " [%s->%s]" % (k, "" if v is None else v) for k, v in transarg.items())
                    write(label, "", args)
                    if label != "":
                        self.labels[label] = pc
                    continue
            elif command in INSTRS:
                if not eat:
                    code = INSTRS[command]
                    args = ""
                    for sub in code[:code.index(" ")]:
                        if sub in "STD":
                            if not spt:
                                self.die(lineno, "Missing arg")
                            arg = spt.pop(0).upper()
                            if arg[:1] not in ("$", "R"):
                                self.die(lineno, "Typo arg")
                            reg = arg[1:]
                            if reg in REGS:
                                outreg = REGS[reg]
                            elif re.match(r"^(\d+|0X[0-9A-F]+|0B[01]+)$", reg):
                                # register number in dec, hex, oct or bin
                                outreg = perl_num(todec(reg.lower()))
                                if outreg >= 32:
                                    self.die(lineno, 'Register number "%s" out of range' % arg)
                            else:
                                self.die(lineno, 'Unknown register "%s"' % arg)
                            args += " $" + str(outreg)
                        elif sub in "IBJH":
                            if not spt:
                                self.die(lineno, "Missing arg")
                            arg = spt.pop(0)
                            if not isnum(arg):
                                arg = arg.upper()
                            args += " " + arg
                    pc += 1
            else:
                self.die(lineno, "Unknown command")

            if eat:
                self.macros[macroname].append(raw)
                continue

            write(label, command, args)
            if not label_done and label != "":
                self.labels[label] = line_pc

        lineno_end = lineno
        out.append(prettyp(lineno_end, 6) + prettyp("", 16) + prettyp(".END", 8) +
                   prettyp("", 16) + "\n")
        out.append("-------------------------------------\n")
        for name, text in self.macros.items():
            out.append("MACRO\t%s\nargs:\t" % name)
            out.append("".join(text) + "\n\n")
        out.append("-------------------------------------\n")
        for name in sorted(self.labels):
            value = perl_num(self.labels[name])
            out.append(prettyp(name, 32) + " = " + hex8(value) + " = " + "%10d\n" % value)
        return out

    # ---- pass 2: list file -> hex file
    def pass2(self, list_lines):
        out = []
        pc = 0
        for line in list_lines:
            line = line.rstrip("\n")
            orig = line
            line = re.sub(r";.*", "", line)
            line = re.sub(r"#.*", "", line)
            line = re.sub(r"^(......)\w+", r"\1", line, count=1)   # remove label
            line = re.sub(r"[\t ,]+", " ", line)
            if re.match(r"^\s*$", line):
                continue
            fields = line.split()
            if len(fields) < 2:
                continue
            lineno, command, rest = fields[0], fields[1], fields[2:]
            args = ""

            if command in DIRECTIVES:
                if command == ".ORG":
                    org = rest.pop(0)
                    filler = perl_num(todec(org)) - pc
                    if filler < 0:
                        self.die(lineno, "ORGing to self or backwards")
                    if filler > 0:
                        out.append("\n" + hex8(pc) + "  /0x00000000 " + prettyp("%d/" % filler, 7) +
                                   "; " + prettyp(lineno, 6) + prettyp(command, 6) + " " + org)
                    pc = perl_num(todec(org))
                elif command == ".PAD":
                    length_s = rest.pop(0)
                    length = self.getvalue(length_s, lineno)
                    data = self.getvalue(rest.pop(0), lineno)
                    out.append(hex8(pc) + "  " + "/" + hex8(data) + " " + prettyp("%d/" % length, 7) +
                               "; " + prettyp(lineno, 6) + prettyp(command, 6) + " " +
                               prettyp(length, 6) + hex8(data))
                    pc += length
                elif command == ".DC":
                    first = True
                    for data in rest:
                        if not first:
                            out.append("\n")
                        first = False
                        outdata = hex8(self.getvalue(data, lineno))
                        out.append(hex8(pc) + "  " + outdata)
                        args += " " + outdata
                        pc += 1
                    out.append("         ; " + prettyp(lineno, 6) + prettyp(command, 6) + args)
                elif command == ".ASCII":
                    first = True
                    right = orig.rfind('"')
                    left = orig.rfind('"', 0, right)
                    string = orig[left + 1:right]
                    i = 0
                    for ch in string:
                        if i % 4 == 0:
                            if not first:
                                out.append("\n")
                            first = False
                            out.append(hex8(pc) + "  0x")
                            pc += 1
                        i += 1
                        out.append(hex2no0x(ord(ch)))
                    if i % 4 == 0:
                        out.append("\n" + hex8(pc) + "  " + hex8(0))
                        pc += 1
                    else:
                        while i % 4 != 0:
                            out.append(hex2no0x(0))
                            i += 1
                    out.append("         ; " + prettyp(lineno, 6) + prettyp(command, 6) + args)
                elif command == ".FILE":
                    out.append("\n" + hex8(pc))
                    fname = rest.pop(0)
                    length = self.getvalue(rest.pop(0), lineno)
                    out.append(" " * 21 + "; " + prettyp(lineno, 6) + prettyp(command, 6) +
                               fname + " " + hex8(length))
                    pc += length
                elif command == ".END":
                    break
            else:
                code = INSTRS.get(command)
                if code is None:
                    self.die(lineno, "Unknown command in list file")
                pars, binv = code[:4], int(code[4:12], 16)
                for sub in pars[:pars.index(" ")] if " " in pars else pars:
                    arg = rest.pop(0) if rest else ""
                    if sub in "STD":
                        arg = re.sub(r"^\$", "", arg)
                        arg = todec(arg)
                        binv |= perl_num(arg) << STD_SHIFT[sub]
                        arg = str(arg)
                        if len(arg) == 1:
                            arg = "0" + arg
                        args += " $" + arg
                    else:
                        relbranch = not isnum(arg)
                        val = self.getvalue(arg, lineno)
                        if sub == "B" and relbranch:
                            val = val - pc - 1   # pc relative if branch to label
                        if sub in "IB":
                            if val < -32768 or val > 65535:
                                self.warn(lineno, "Integer arg exceeds 16 bits")
                            val &= 0xffff
                            args += " " + hex4(val)
                        elif sub == "J":
                            if val < 0 or val > 0x03ffffff:
                                self.warn(lineno, "Integer arg exceeds 26 bits")
                            val &= 0x03ffffff
                            args += " " + hex8(val)
                        elif sub == "H":
                            if val < 0 or val > 0x1f:
                                self.warn(lineno, "SHAMT exceeds 5 bits")
                            val = (val & 0x1f) << 6
                            args += " " + hex2(val)
                        binv |= val
                out.append(hex8(pc) + "  " + hex8(binv) + "         ; " +
                           prettyp(lineno, 6) + prettyp(command, 6) + prettyp(args, 16))
                self.code.append((pc, binv, lineno, command, args.strip()))
                pc += 1
            out.append("\n")
        return "".join(out)

    # ---- pass 3: hex file -> binary
    def pass3(self, hex_text):
        out = bytearray()

        def h8(s):
            s = (s + "00000000")[:8]
            return bytes.fromhex(s)

        for line in hex_text.splitlines(keepends=True):
            if re.match(r"^\s*$", line):
                continue
            line = re.sub(r"^.{12}", "", line, count=1)
            if ".FILE" in line:
                f = perl_split(r"\s+", line)
                fname, length = f[4], perl_num(todec(f[5]))
                try:
                    with open(fname, "rb") as fh:
                        data = fh.read(4 * length)
                        if len(fh.read(4)) == 4:   # a whole word or more left out
                            sys.stderr.write("warning: .file %s truncated to %d words (file is %d bytes)\n"
                                             % (fname, length, os.path.getsize(fname)))
                except OSError:
                    raise AsmError("Could not find incbin file %s" % fname)
                out += data + bytes(4 * length - len(data))
            elif line.startswith("/"):
                f = line.replace("/", "").split()
                data, amount = f[0], perl_num(f[1])
                data = re.sub(r"0[xX]", "", data, count=1)
                out += h8(data) * amount
            else:
                word = re.sub(r"\s.*", "", line, flags=re.S)
                word = re.sub(r"0[xX]", "", word, count=1)
                out += h8(word)
        return bytes(out)

    def run(self, hazards="error", suggest_nops=False, remove_nops=None):
        try:
            with open(self.namei, encoding="latin-1", newline="") as f:
                src = f.read().splitlines(keepends=True)
        except OSError:
            raise AsmError("Could not open input file!")
        list_lines = self.pass1(src)
        with open(self.name1, "w", encoding="latin-1", newline="") as f:
            f.write("".join(list_lines))
        hex_text = self.pass2("".join(list_lines).splitlines(keepends=True))
        with open(self.name2, "w", encoding="latin-1", newline="") as f:
            f.write(hex_text)
        if hazards != "off":
            errors, warnings = check_hazards(self.code)
            for lineno, msg in warnings:
                sys.stderr.write("%s:%s: warning: %s\n" % (self.namei, lineno, msg))
            kind = "error" if hazards == "error" else "warning"
            for lineno, msg in errors:
                sys.stderr.write("%s:%s: %s: %s\n" % (self.namei, lineno, kind, msg))
            if errors and hazards == "error":
                if os.path.exists(self.name3):
                    os.remove(self.name3)
                raise AsmError("%s: %d pipeline hazard error(s), no %s written "
                               "(see rtl/processor/PIPELINE_HAZARDS.md, "
                               "--hazards=warn to override)" % (self.namei, len(errors), self.name3))
        with open(self.name3, "wb") as f:
            f.write(self.pass3(hex_text))
        if suggest_nops or remove_nops:
            sys.stdout.write(nop_report(self.code, self.namei, self.labels, src, remove_nops))


# ------------------------------------------------------------ hazard checker
# Rules from rtl/processor/PIPELINE_HAZARDS.md:
#   * branches, jr, jalr: 3 delay slots; j, jal: 1 delay slot (always executed)
#   * no branch/jump in a delay slot
#   * a register written by instruction P and read by C, d instructions later
#     in execution order (d = 1 is the next instruction). d = 1, 2 are
#     forwarded, d = 3 is covered by the register file write-through:
#       - lw / jal / jalr result at d = 1 is wrong (address / 0 is forwarded)
#       - sw data register (rt) is not forwarded: needs d >= 3
#   * jal delay slot is executed again after return (jal + 1): warn if not nop

BRANCH_OPS = {1, 4, 5, 7}       # bge, beq, bne, bgt


def _decode(w):
    """-> (kind, sources, dest, sw_data_reg, target_info)"""
    op, rs, rt, rd, fn = w >> 26, (w >> 21) & 31, (w >> 16) & 31, (w >> 11) & 31, w & 63
    if w == 0:
        return "nop", set(), None, None
    if op == 0:
        if fn == 8:
            return "jr", {rs}, None, None
        if fn == 9:
            return "jalr", {rs}, 31, None
        return "alu", {rs, rt}, rd, None
    if op == 2:
        return "j", set(), None, None
    if op == 3:
        return "jal", set(), 31, None
    if op in BRANCH_OPS:
        return "branch", {rs, rt}, None, None
    if op == 0x23:
        return "lw", {rs}, rt, None
    if op == 0x2b:
        return "sw", {rs}, None, rt
    if op in (0x10, 0x11, 0x12, 0x13):
        return "mfc", set(), rd, None
    if op == 0x0f:
        return "alu", set(), rt, None                  # lui
    return "alu", {rs}, rt, None                       # immediate ALU ops


SLOTS = {"branch": 3, "jr": 3, "jalr": 3, "j": 1, "jal": 1}


class _Program:
    """Instruction list for the hazard checker. Instructions can be removed
    (to try out nop removal): the following instructions then move up, and
    branch / jump targets pointing at a removed instruction move to the next."""

    def __init__(self, code):
        self.code = sorted(code)
        self.n = len(self.code)
        self.dec = [_decode(c[1]) for c in self.code]
        index = {c[0]: i for i, c in enumerate(self.code)}
        # sequential successor in the original layout (None at a code gap)
        self.orig_next = [index.get(c[0] + 1) for c in self.code]
        self.target = [None] * self.n
        self.always = [False] * self.n
        for i, (pc, w, _, _, _) in enumerate(self.code):
            kind = self.dec[i][0]
            if kind == "branch":
                off = w & 0xffff
                off = off - 0x10000 if off & 0x8000 else off
                self.target[i] = index.get(pc + 1 + off)
                self.always[i] = (w >> 26) == 4 and ((w >> 21) & 31) == ((w >> 16) & 31)
            elif kind in ("j", "jal"):
                self.target[i] = index.get(w & 0x03ffffff)

    def desc(self, i):
        c = self.code[i]
        return "%s %s (line %s)" % (c[3], c[4], c[2])

    def check(self, removed=frozenset()):
        """-> (errors, warnings), lists of (lineno, message)"""
        errors, warnings = [], []
        dec = self.dec
        live = [i for i in range(self.n) if i not in removed]

        def skip(i):
            while i is not None and i in removed:
                i = self.orig_next[i]
            return i

        nxt = {i: skip(self.orig_next[i]) for i in live}
        succ = {i: {nxt[i]} - {None} for i in live}
        return_points = {nxt[i] for i in live if dec[i][0] in ("jal", "jalr")} - {None}

        for i in live:
            kind = dec[i][0]
            if kind not in SLOTS:
                continue
            slot, last = i, i
            for k in range(1, SLOTS[kind] + 1):
                slot = nxt.get(slot)
                if slot is None:
                    break
                last = slot
                if dec[slot][0] in SLOTS:
                    errors.append((self.code[slot][2], "%s in delay slot %d of %s" %
                                   (self.code[slot][3], k, self.desc(i))))
            if slot is None:
                continue
            target = skip(self.target[i])
            if kind == "branch":
                succ[last] = ({target} if self.always[i] else {nxt[last], target}) - {None}
            elif kind == "j":
                succ[last] = {target} - {None}
            elif kind == "jal":
                # after the return the delay slot continues to the next instruction
                succ[last] = {target, nxt[last]} - {None}
                if dec[last][0] != "nop":
                    warnings.append((self.code[last][2], "jal delay slot %s is executed again after "
                                     "the return (return address = jal + 1)" % self.desc(last)))
            else:   # jr / jalr: assume a return to any jal/jalr + 1
                succ[last] = set(return_points)

        pred = {i: set() for i in live}
        for i, ss in succ.items():
            for t in ss:
                pred[t].add(i)

        seen = set()

        def report(c, p, reg, d, why):
            if (c, p, reg, why) not in seen:
                seen.add((c, p, reg, why))
                errors.append((self.code[c][2], "$%d written by %s at distance %d: %s" %
                               (reg, self.desc(p), d, why)))

        def walk(c, reg, role, path):
            # path: instructions executed before the consumer, nearest first
            d = len(path)
            p = path[-1]
            kind, _, dest, _ = dec[p]
            if dest == reg:
                if role == "sw data":
                    report(c, p, reg, d, "sw data register is not forwarded, needs distance >= 3")
                elif d == 1 and kind == "lw":
                    report(c, p, reg, d, "lw result is not available at distance 1 (1 nop needed)")
                elif d == 1 and kind in ("jal", "jalr"):
                    report(c, p, reg, d, "$ra is not available in the jump delay slot")
                return
            if d < 2:
                for q in pred[p]:
                    walk(c, reg, role, path + [q])

        for c in live:
            kind, src, _, swdata = dec[c]
            regs = [(r, "source") for r in src if r != 0]
            if swdata:
                regs.append((swdata, "sw data"))
            for reg, role in regs:
                for q in pred[c]:
                    walk(c, reg, role, [q])

        errors.sort(key=lambda e: int(e[0]))
        warnings.sort(key=lambda e: int(e[0]))
        return errors, warnings

    def delay_slot_set(self):
        slots = set()
        for i in range(self.n):
            kind = self.dec[i][0]
            if kind in SLOTS:
                s = i
                for _ in range(SLOTS[kind]):
                    s = self.orig_next[s]
                    if s is None:
                        break
                    slots.add(s)
        return slots

    def suggest_nop_removal(self):
        """Greedy: try to remove every nop that is not in a delay slot, keep
        the removal if the program stays free of hazard errors and does not get
        new warnings. Returns the set of removable instruction indexes."""
        errors, warnings = self.check()
        if errors:
            return None
        slots = self.delay_slot_set()
        removed = set()
        for i in range(self.n):
            if self.dec[i][0] != "nop" or i in slots:
                continue
            e, w = self.check(frozenset(removed | {i}))
            if not e and len(w) <= len(warnings):
                removed.add(i)
        return removed


def check_hazards(code):
    """code: list of (pc, word, lineno, mnemonic, args) -> (errors, warnings)"""
    return _Program(code).check()


def nop_report(code, name, labels=None, src_lines=None, out_name=None):
    """Report of nops that can be removed (see suggest_nop_removal).
    If out_name is given, also write a copy of the source without them
    (only lines that contain nothing but a nop are removed)."""
    prog = _Program(code)
    removable = prog.suggest_nop_removal()
    if removable is None:
        return "%s: fix the pipeline hazard errors before looking for removable nops\n" % name
    at_label = {}
    for lab, val in (labels or {}).items():
        if isinstance(val, int):
            at_label.setdefault(val, lab)
    slots = prog.delay_slot_set()
    out = []
    total = sum(1 for d in prog.dec if d[0] == "nop")
    in_slots = sum(1 for i in slots if prog.dec[i][0] == "nop")
    # group runs of consecutive nops
    i = 0
    while i < prog.n:
        if prog.dec[i][0] != "nop":
            i += 1
            continue
        run = [i]
        while prog.orig_next[run[-1]] is not None and prog.dec[prog.orig_next[run[-1]]][0] == "nop":
            run.append(prog.orig_next[run[-1]])
        i = run[-1] + 1
        rm = [k for k in run if k in removable]
        if not rm:
            continue
        lines = sorted({prog.code[k][2] for k in run}, key=int)
        where = lines[0] if len(lines) == 1 else "%s-%s" % (lines[0], lines[-1])
        prev = run[0] - 1
        pc0 = prog.code[run[0]][0]
        if pc0 in at_label:
            after = "at label %s" % at_label[pc0]
        elif prev >= 0 and prog.orig_next[prev] == run[0]:
            after = "after " + prog.desc(prev)
        else:
            after = "at start of code"
        nxt = prog.orig_next[run[-1]]
        before = prog.desc(nxt) if nxt is not None else "end"
        keep = len(run) - len(rm)
        out.append("%s:%s: remove %d of %d nop%s (keep %d)   %s, before %s\n" %
                   (name, where, len(rm), len(run), "s" if len(run) > 1 else "", keep, after, before))
    out.append("%s: %d of %d nops can be removed (%d nops are in delay slots and are kept; "
               "%d instructions -> %d)\n" %
               (name, len(removable), total, in_slots, prog.n, prog.n - len(removable)))

    if out_name and src_lines is not None:
        # instructions per source line: only remove lines that are a single nop
        per_line = {}
        for c in prog.code:
            per_line[int(c[2])] = per_line.get(int(c[2]), 0) + 1
        drop, kept = set(), 0
        for k in removable:
            ln = int(prog.code[k][2])
            text = src_lines[ln - 1] if ln - 1 < len(src_lines) else ""
            if per_line[ln] == 1 and re.match(r"^\s+nop\s*([;#].*)?$", text, re.I):
                drop.add(ln)
            else:
                kept += 1
        with open(out_name, "w", encoding="latin-1", newline="") as f:
            f.write("".join(t for n, t in enumerate(src_lines, 1) if n not in drop))
        out.append("%s: wrote %s with %d nop lines removed%s\n" %
                   (name, out_name, len(drop),
                    "" if not kept else " (%d nops from macros left in place)" % kept))
    return "".join(out)

def main(argv):
    ap = argparse.ArgumentParser(description="TetrIC assembler (prg.s -> prg.1, prg.2, prg.bin)")
    ap.add_argument("source")
    ap.add_argument("--hazards", choices=("error", "warn", "off"), default="error",
                    help="pipeline hazard check: error (default, no .bin written), "
                         "warn (report only) or off")
    ap.add_argument("--suggest-nops", action="store_true",
                    help="list nops that can be removed without breaking the pipeline rules")
    ap.add_argument("--remove-nops", metavar="OUT.s",
                    help="like --suggest-nops, and write a copy of the source without those nops")
    a = ap.parse_args(argv[1:])
    try:
        Assembler(a.source).run(hazards=a.hazards, suggest_nops=a.suggest_nops,
                                remove_nops=a.remove_nops)
    except AsmError as e:
        sys.stderr.write("%s\n" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
