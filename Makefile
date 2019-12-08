.PHONY: run
run: main
	cat sys.f - | ./main

main: main.asm impl.asm
	fasm $< $@

.PHONY: clean
clean:
	rm -f main
