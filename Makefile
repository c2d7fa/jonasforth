main: main.asm impl.asm
	fasm $< $@

.PHONY: clean
clean:
	rm -f main
