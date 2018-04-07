# The ka1 variant has 1KB of flash, the ka2 2KB
class mc9rs08kaX:
	def __init__(self, variant):
		self.variant = variant
		self.labels = {
			"D[X]":     0x0E,
			"X":        0x0F,
			".PTAD":    0x10,
			".PTADD":   0x11,
			".ACMPSC":  0x13,
			".ICSC1":   0x14,
			".ICSC2":   0x15,
			".ICSTRM": 0x16,
			".ICSSC":   0x17,
			".MTIMSC":  0x18,
			".MTIMCLK": 0x19,
			".MTIMCNT": 0x1A,
			".MTIMMOD": 0x1B,
			".KBISC":   0x1C,
			".KBIPE":   0x1D,
			".KBIES":   0x1E,
			".PAGESEL": 0x1F,

			".SRS": 0x200,
			".SOPT": 0x201,
			".SIP1": 0x202,

			".SDIDH": 0x206,
			".SDIDL": 0x207,
			".SRTISC": 0x208,
			".SPMSC1": 0x209,

			".FOPT": 0x210,
			".FLCR": 0x211,

			".PTAPE": 0x220,
			".PTAPUD": 0x221,
			".PTASE": 0x222,

			".NVOPT": 0x3FFC,

			".FLASHBASE": 0x3800 if variant == 2 else 0x3C00,
			".RESET": 0x3FFD # Where the CPU resets to
		}
		pass

	def isValidAddress(self, address):
		return address <= 0x3FFF

	def isRam(self, address):
		return False

	def getRamQuantity(self):
		return 14 + 48

	def isFlash(self, address):
		return address >= self.labels[".FLASHBASE"] and address <= 0x3FFF

	def getFlashQuantity(self):
		if self.variant == 2:
			return 2048
		return 1024

	def flashRowId(self, address):
		return (address - self.labels[".FLASHBASE"]) >> 6
