import math
import string

# Generates a rs08asm class
class rs08asm:
	def __init__(self):
		self.instructions = []
		self.address = 0
		self.labels = {}
		pass

	def at(self, address):
		self.address = address

	def label(self, label):
		self.labels[label] = self.address

	def assemble(self):
		memory = {}

		# Turn each instruction into bytes
		for address, fmt, arguments, values in self.instructions:
			nextPc = address + encode(fmt, [], True)[1]
			args = []
			for argSpec, value in zip(arguments, values):
				args.append(self._processArgument(argSpec, value, nextPc))

			bitstring, size = encode(fmt, args)
			for i in range(size):
				memory[address + i] = int(bitstring[i*8:(i+1)*8], 2)
			pass
		return memory

	def _processArgument(self, argumentSpec, value, nextPc):
		if argumentSpec == "n":
			return self._labelOrLiteral(value, 3)
		elif argumentSpec == "x":
			return self._labelOrLiteral(value, 4)
		elif argumentSpec == "8i":
			return value # This better be a literal value!
		elif argumentSpec == "4a":
			return self._labelOrLiteral(value, 4)
		elif argumentSpec == "5a":
			return self._labelOrLiteral(value, 5)
		elif argumentSpec == "8a":
			return self._labelOrLiteral(value, 8)
		elif argumentSpec == "16a":
			return self._labelOrLiteral(value, 16)
		elif argumentSpec == "rel":
			value = self._labelOrLiteral(value, 16)
			diff = value - nextPc
			if diff < -128 or diff > 127:
				raise Exception("Cannot create relative address going from '%s' to '%s', diff='%s'"%(nextPc, value, diff))
			return diff&0xFF
		else:
			raise Exception("Unknown argumentSpec %s"%argumentSpec)
		pass

	def _labelOrLiteral(self, value, maxValueBits=-1):
		# Dereferenced index register
		if isinstance(value, str) and value.lower() == "d[x]":
			return 0x0e

		# Index register
		if isinstance(value, str) and value.lower() == "x":
			return 0x0f

		v = self.labels.get(value, value)
		if maxValueBits > 0 and v >= math.pow(2, maxValueBits):
			raise Exception("Value '%s' exceeds maximum field size '%s' for type, from '%s'"%(v, maxValueBits, value))
		return v

	def _add(self, fmt, arguments, values):
		self.instructions.append((self.address, fmt, arguments, values))
		self.address += encode(fmt, None, True)[1]
		pass
	pass

def encode(fmt, values, justGetSize=False):
	"""
	The specification for fmt is as follows:
	* All whitespace is ignored and the string is lowercased before processing.
	* An "x" signifies that the next two characters represent an 8-bit hex value
	* A "*N" where "N" is a number between 0 and 9 (inclusive) indicates that
	    the previous symbol should be replicated N times.
	* A 0 or 1 is a literal bit value
	* If a letter occurs in the string exactly once, it is expanded to be 8
	    bits long.
	* A letter (other than x, such as "a" or "b") refers to the corresponding
	    value in the values array, so "a" is the first value, "b" is the second,
	    and so forth. Each individual letter corresponds to a single bit. The
	    last letter to appear is the lowest bit, the second to last is the
	    second lowest bit, and so forth.
	* If the result is not a multiple of 8 bits long, the result is invalid.
	"""

	# Remove the spaces
	fmt = "".join(list(filter(lambda c: c != " ", fmt.lower())))

	# Troll for x's
	result = ""
	i = 0
	while i < len(fmt):
		if fmt[i] == "x":
			result += "{0:08b}".format(int(fmt[i+1] + fmt[i+2], 16))
			i += 2
		else:
			result += fmt[i]
		i += 1

	# Check for multipliers
	i = 0
	tmp = result
	result = ""
	while i < len(tmp):
		if i < len(tmp)-1 and tmp[i+1] == "*":
			result += tmp[i] * int(tmp[i+2])
			i += 2
		else:
			result += tmp[i]
		i += 1

	i = 0
	tmp = result
	result = ""
	while i < len(tmp):
		if tmp[i] in string.ascii_lowercase and tmp.count(tmp[i]) == 1:
			result += tmp[i] * 8
		else:
			result += tmp[i]
		i += 1

	if justGetSize:
		return None, int(len(result)/8)

	# Apply letters
	i = 0
	tmp = result
	result = ""
	seenCount = {}
	while i < len(tmp):
		if tmp[i] in string.ascii_lowercase:
			bitsFromTop = seenCount.get(tmp[i], 0)
			seenCount[tmp[i]] = bitsFromTop + 1
			numBits = tmp.count(tmp[i])
			value = values[ord(tmp[i]) - ord("a")]
			result += "1" if (value >> (numBits - bitsFromTop - 1))&0x01 == 1 else "0"
		else:
			result += tmp[i]
		i += 1
	return result, int(len(result)/8)

def buildmethod(fmt, arguments):
	def method(self, *values):
		self._add(fmt, arguments, values)
		return self
	return method

def rs08asmgen():
	INSTRUCTIONS = [
		("adci", "8i", "xA9 a"),
		("adc",  "8a", "xB9 a"),
		("addi", "8i", "xAB a"),
		("addt", "4a", "0110aaaa"), # Add Tiny
		("add",  "8a", "xBB a"),
		("andi", "8i", "xA4 a"),
		("and",  "8a", "xB4 a"),
		("asla", "x48"),
		("bcc", "rel", "x34 a"),
		("bclr", "n", "8a", "0001 aaa1 b*8"),
		("bcs", "rel", "x35 a"),
		("beq", "rel", "x37 a"),
		("bgnd", "xBF"),
		("bhs", "rel", "x34 a"),
		("blo", "rel", "x35 a"),
		("bne", "rel", "x36 a"),
		("bra", "rel", "x30 a"),
		("brn", "rel", "x30 x00"),
		("brclr", "n", "8a", "rel", "0000 aaa1 b c"),
		("brset", "n", "8a", "rel", "0000 aaa0 b c"),
		("bset", "n", "8a", "0001 aaa0 b"),
		("bsr", "rel", "xAD a"),
		("cbeqa", "8i", "rel", "x41 a b"),
		("cbeq", "8a", "rel", "x31 a b"),
		("clc", "x38"),
		("clr", "8a", "x3F a"),
		("clrt","5a", "100a aaaa"), # Clear Tiny
		("clra", "x4F"),
		("cmpi", "8i", "xA1 a"),
		("cmp", "8a", "xB1 a"),
		("coma", "x43"),
		("dbnz", "8a", "rel", "x3B a b"),
		("dbnza", "rel", "x4B a"),
		("dec", "8a", "x3A a"),
		("dect", "4a", "0101 aaaa"),
		("deca", "x4A"),
		("eori", "8i", "xA8 a"),
		("eor", "8a", "xB8 a"),
		("inc", "8a", "x3C a"),
		("inct", "4a", "0010 aaaa"),
		("inca", "x4C"),
		("jmp", "16a", "xBC a*8a*8"),
		("jsr", "16a", "xBD a*8a*8"),
		("ldai", "8i", "xA6 a"),
		("lda", "8a", "xB6 a"),
		("ldat", "5a", "110a aaaa"),
		("ldxi", "8i", "x3E a x0F"),
		("ldx", "8a", "x4E a x0F"),
		("lsla", "x48"),
		("lsra", "x44"),
		("mov", "8a", "8a", "x4E a b"),
		("movi","8i", "8a", "x3E a b"),
		("nop", "xAC"),
		("orai", "8i", "xAA a"),
		("ora", "8a", "8a", "xBA a b"),
		("rola", "x49"),
		("rora", "x46"),
		("rts", "xBE"),
		("sbci", "8i", "xA2 a"),
		("sbc", "8a", "xB2 a"),
		("sec", "x39"),
		("sha", "x45"),
		("sla", "x42"),
		("sta", "8a", "xB7 a"),
		("stat", "5a", "111a aaaa"),
		("stx", "8a", "x4E x0F a"),
		("stop", "xAE"),
		("subi", "8i", "xA0 a"),
		("sub", "8a", "xB0 a"),
		("subt", "4a", "0111 aaaa"),
		("tax", "xEF"),
		# tst isn't implemented
		("tsta", "xAA x00"),
		("txa", "xCF"),
		("wait", "xAF")
	]

	for instruction in INSTRUCTIONS:
		name = instruction[0]
		fmt = instruction[-1]
		arguments = instruction[1:-1]
		setattr(rs08asm, name, buildmethod(fmt, arguments))
	pass

rs08asmgen()

if __name__ == "__main__":
	p = rs08asm()
	p.at(0x30)
	p.label("main")
	p.movi(0x01, 0x10)
	p.movi(0x01, 0x11)
	p.bra("main") # Branch always could just as well be jmp

	print(p.assemble())
