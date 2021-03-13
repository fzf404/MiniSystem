default :
	 make.exe -r Linux.img

bootsect.bin : bootsect.asm  Makefile
	NASM bootsect.asm -o bootsect.bin -l bootsect.lst

setup.bin : setup.asm  Makefile
	NASM setup.asm -o setup.bin  -l setup.lst

head.bin : head.asm  Makefile
	NASM head.asm -o head.bin -l head.lst

Linux.img: bootsect.bin setup.bin head.bin Makefile
	copy /B bootsect.bin+setup.bin+head.bin  Linux.img

run :
	make.exe
	# VMWARE  -x   ../../VWare/Linux/Linux.vmx