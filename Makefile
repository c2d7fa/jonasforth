main: main.asm
	fasm $< $@

.PHONY: clean
clean:
	rm -f main
